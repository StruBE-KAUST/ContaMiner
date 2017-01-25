#!/bin/sh

##    Copyright (C) 2016 King Abdullah University of Science and Technology
##
##    This program is free software; you can redistribute it and/or modify
##    it under the terms of the GNU General Public License as published by
##    the Free Software Foundation; either version 2 of the License, or
##    (at your option) any later version.
##
##    This program is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License along
##    with this program; if not, write to the Free Software Foundation, Inc.,
##    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

## Install ContaMiner
# This file try to find the installation directory of CCP4 and MoRDa.
# If not found, the scripts stops.
# If found, the paths are written in define_paths.sh

# Move to directory where install.sh is
CM_PATH="$(dirname "$(readlink -f "$0")")"
{
    cd "$CM_PATH"
} || {
    printf "Error when moving to %s.\n" "$CM_PATH"
    exit 1
}

# Change to POSIX mode
{
    . "scripts/posix_mode.sh"
} || {
    printf "Directory seems corrupted. Please check.\n"
    exit 1
}

### Try to find CCP4 installation ###
printf "Finding CCP4 installation... "
ccp4_path=""

# Source define_paths, in case of re-run install.sh after previous installation
if [ -f "scripts/define_paths.sh" ]
then
    # shellcheck source=templates/define_paths.sh.tpl
    . "scripts/define_paths.sh" 2>/dev/null
    if [ -n "$SOURCE1" ]
    then
        # shellcheck source=/dev/null
        . "$SOURCE1"
    fi
    if [ -n "$SOURCE2" ]
    then
        # shellcheck source=/dev/null
        . "$SOURCE2"
    fi
    if [ -n "$SOURCE3" ]
    then
        # shellcheck source=/dev/null
        . "$SOURCE3"
    fi
fi

# Success if user sourced CCP4, or define_paths.sh is initialized
ccp4_path=$(which --skip-alias --skip-functions molrep 2>/dev/null)

# Try to find the setup scripts in common locations
ccp4_name="bin/ccp4.setup-sh\$"
if [ -z "$ccp4_path" ]
then
    ccp4_path=$(locate -ql1 --regex "$ccp4_name" 2>/dev/null)
fi
# From this step, find is I/O intensive and can be slow. Ask user if he wants
# to continue
if [ -z "$ccp4_path" ]
then
    printf "[FAILED]\nDo you want to search harder ? [Y/n] "
    read -r answer
    case $answer in
        [nN])
            ;;
        *)
            printf "Finding CPP4 installation (harder)... "
            if [ -z "$ccp4_path" ]
            then
                ccp4_path=$( \
                    find /opt -regex ".*$ccp4_name" 2>/dev/null \
                    | head -n1)
            fi
            if [ -z "$ccp4_path" ]
            then
                ccp4_path=$( \
                    find "$HOME" -regex ".*$ccp4_name" 2>/dev/null \
                    | head -n1)
            fi
            if [ -z "$ccp4_path" ]
            then
                printf "[FAILED]\n"
            fi
            ;;
    esac
fi

# Exit 1 if not found
if [ -z "$ccp4_path" ]
then
    printf "Please source bin/ccp4.setup-sh before running %s.\n" "$0"
    exit 1
fi

# ccp4_path contains the full path to $ccp4_name or molrep, not the main dir
ccp4_path="$(dirname "$(dirname "$ccp4_path")")"
printf "[OK]\n"


### Try to find MoRDa installation ###
printf "Finding MoRDa installation... "
morda_path=""

# Try if the user sourced the script from morda
morda_path=$(which --skip-alias --skip-functions morda 2>/dev/null)
if [ -n "$morda_path" ]
then
    morda_path="$(dirname "$morda_path")"
fi

# Try to find the setup script in common locations
morda_name="morda_env_sh\$"
if [ -z "$morda_path" ]
then
    morda_path=$(locate -ql1 --regex "$morda_name" 2>/dev/null)
fi
# From this step, find is I/O intensive and can be slow. Ask user if he wants
# to continue.
if [ -z "$morda_path" ]
then
    printf "[FAILED]\nDo you want to search harder ? [Y/n] "
    read -r answer
    case $answer in
        [nN])
            ;;
        *)
            printf "Finding MoRDa installation (harder)... "
            if [ -z "$morda_path" ]
            then
                morda_path=$( \
                    find /opt -regex ".*$morda_name" 2>/dev/null \
                    | head -n1)
            fi
            if [ -z "$morda_path" ]
            then
                morda_path=$( \
                    find "$HOME" -regex ".*$morda_name" 2>/dev/null \
                    | head -n1)
            fi
            if [ -z "$ccp4_path" ]
            then
                printf "[FAILED]\n"
            fi
            ;;
    esac
fi

# Exit 1 if not found
if [ -z "$morda_path" ]
then
    printf "Please source morda_env_sh before running %s.\n" "$0"
    exit 1
fi

# morda_path contains the full path to $morda_name or morda bin dir
morda_path="$(dirname "$morda_path")"
printf "[OK]\n"


### Write sources in define_paths.sh ###
# Define full path to scripts
source1="$ccp4_path/setup-scripts/ccp4.setup-sh"
source2="$ccp4_path/bin/ccp4.setup-sh"
source3="$morda_path/morda_env_sh"

# Write file
define_paths_template="templates/define_paths.sh.tpl"
define_paths="scripts/define_paths.sh"
{
    cp -T "$define_paths_template" "$define_paths"
} || {
    printf "Error: Unable to copy " >&2
    printf "%s to %s.\n" "$define_paths_template" "$define_paths" >&2
    exit 1
}

{
    sed -i "s,SOURCE1=.*,SOURCE1=\"$source1\"," $define_paths
    sed -i "s,SOURCE2=.*,SOURCE2=\"$source2\"," $define_paths
    sed -i "s,SOURCE3=.*,SOURCE3=\"$source3\"," $define_paths
} || {
    printf "Error: Unable to write file %s.\n" "$define_paths" >&2
    exit 1
}

# Copy sbatch options in sbatch scripts
prep_options_file="init/prep_options.slurm"
prep_template="templates/CM_prep.slurm.tpl"
prep_script="scripts/CM_prep.slurm"

cmd_line=':a;N;$!ba;s/## START.*## END/## START\n'
cmd_line="$cmd_line$(tr '\n' '\r' < $prep_options_file | sed 's/\r/\\n/g')"
cmd_line="$cmd_line"'\n## END/g'
{
    sed "$cmd_line" "$prep_template" > "$prep_script"
} || {
    printf "Error: Unable to write file %s.\n" "$prep_script" >&2
    exit 1
}


run_options_file="init/run_options.slurm"
run_template="templates/CM_solve.slurm.tpl"
run_script="scripts/CM_solve.slurm"

cmd_line=':a;N;$!ba;s/## START.*## END/## START\n'
cmd_line="$cmd_line$(tr '\n' '\r' < $run_options_file | sed 's/\r/\\n/g')"
cmd_line="$cmd_line"'\n## END/g'
{
    sed "$cmd_line" "$run_template" > "$run_script"
} || {
    printf "Error: Unable to write file %s.\n" "$run_script" >&2
    exit 1
}


# Add the $CM_PATH indication to contaminer main script
# $CM_PATH is defined on the top of this file
cm_template="templates/contaminer.tpl"
cm_main="contaminer"
{
    sed "s,CM_PATH=.*,CM_PATH=\"$CM_PATH\"," "$cm_template" > "$cm_main"
    chmod +x "$cm_main"
} || {
    printf "Error: Unable to modify %s.\n" "$cm_main" >&2
    exit 1
}

# Copy sg_scores from init to data
template_file="$CM_PATH/init/sg_scores.txt"
data_file="$CM_PATH/data/sg_scores.txt"
{
    cp -T "$template_file" "$data_file"
} || {
    printf "Error: Unable to copy " >&2
    printf "%s to %s.\n" "$template_file" "$data_file" >&2
    exit 1
}


### Ask is we should start the DB initialisation
printf "Do you want to initialize ContaBase ? [Y/n] "
read -r answer
case $answer in 
    [nN])
        printf "Initialization skipped. You can initialize ContaBase by "
        printf "running:\n  contaminer initialize\n\n"
        ;;
    *)
        {
            sh contaminer initialize
        } || {
            printf "Error while initializing the contabase.\n" >&2
            exit 1
        }
        printf "When the jobs are completed, the initialization is finished. "
        printf "To check the running jobs, you can use :\n"
        printf "  squeue -u %s\n\n" "$(whoami)"
        ;;
esac

printf "Installation complete"
