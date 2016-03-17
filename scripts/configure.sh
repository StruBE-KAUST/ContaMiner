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

## configure.sh version 1.0.0
## Installation of required tools and configuration of ContaMiner

# Retrieve paths
if [ -z "$define_paths" ]
then
    printf "Do not use this script. "
    printf "Please run install.sh in the root directory.\n"
    exit 1
fi

### Try to find CCP4 installation ###
printf "Finding CCP4 installation... "
ccp4_path=""

# Try if the user sourced the scripts from CCP4
ccp4_path=$(whereis molrep 2>/dev/null | cut --delimiter=':' -f 2-)

# Try to find the setup scripts in common locations
ccp4_name="bin/ccp4.setup-sh\$"
if [ -z "$ccp4_path" ]
then
    ccp4_path=$(locate -ql1 --regex "$ccp4_name" 2>/dev/null)
fi
if [ -z "$ccp4_path" ]
then
    ccp4_path=$(find /opt -regex ".*$ccp4_name" 2>/dev/null | head -n1)
fi

# whereis could have shown no result, even if installation is sourced
if [ -z "$ccp4_path" ]
then
    sp_path=$(printf "$PATH" | sed -e 's/:/ /g')
    ccp4_path=$(find $sp_path -regex ".*$ccp4_name" 2>/dev/null | head -n1)
fi

if [ -z "$ccp4_path" ]
then
    printf "[FAILED]\n"
    printf "Try to source bin/ccp4.setup-sh before installing ContaMiner.\n"
    exit 1
fi

# ccp4_path contains the full path to $ccp4_name or molrep, not the main dir
ccp4_path=$(dirname $(dirname $ccp4_path))

printf "[OK]\n"

### Try to find MoRDa installation ###
printf "Finding MoRDa installation... "
morda_path=""

# Try if the user sourced the script from morda
morda_path=$(whereis morda 2>/dev/null | cut --delimiter=':' -f 2-)
if [ -n "$morda_path" ]
then
    morda_path=$(dirname $morda_path)
fi

# Try to find the setup script in common locations
morda_name="morda_env_sh\$"
if [ -z "$morda_path" ]
then
    morda_path=$(locate -ql1 --regex "$morda_name" 2>/dev/null)
fi  
if [ -z "$morda_path" ]
then
    morda_path=$(find /opt -regex ".*$morda_name" 2>/dev/null | head -n1)
fi

# Same same, but different. whereis etc.
if [ -z "$morda_path" ]
then
    sp_path=$(printf "$PATH" | sed -e 's/:/ /g')
    morda_path=$(find $sp_path -regex ".*/morda_prep$" 2>/dev/null | head -n1)
    morda_path=$(dirname "$morda_path")
fi

if [ -z "$morda_path" ]
then
    printf "[FAILED]\n"
    printf "Try to source setup_morda before installing ContaMiner.\n"
    exit 1
fi

# morda_path contains the full path to $morda_name or morda bin dir
morda_path=$(dirname $morda_path)

printf "[OK]\n"

### Write sources in paths script ###
# Define full path to scripts
source1="$ccp4_path/setup-scripts/ccp4.setup-sh"
source2="$ccp4_path/bin/ccp4.setup-sh"
source3="$morda_path/morda_env_sh"

# Write file
sed -i "s,source1=.*,source1=\"$source1\"," $define_paths
sed -i "s,source2=.*,source2=\"$source2\"," $define_paths
sed -i "s,source3=.*,source3=\"$source3\"," $define_paths

. "$define_paths"

# Copy sbatch options in sbatch scripts
run_options_file="$init_path/run_options.sh"
cmd_line=':a;N;$!ba;s/## START.*## END/## START\n'
cmd_line="$cmd_line$(cat ${run_options_file} | tr '\n' '\r' | sed 's/\r/\\n/g')"
cmd_line="$cmd_line"'\n## END/g'
sed -i "$cmd_line" "$scripts_path/sbatch_run.sh"

prep_options_file="$init_path/prep_options.sh"
cmd_line=':a;N;$!ba;s/## START.*## END/## START\n'
cmd_line="$cmd_line$(cat ${prep_options_file} | tr '\n' '\r' |sed 's/\r/\\n/g')"
cmd_line="$cmd_line"'\n## END/g'
sed -i "$cmd_line" "$scripts_path/sbatch_prep.sh"
