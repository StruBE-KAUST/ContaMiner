#!/bin/sh

##    Copyright (C) 2017 King Abdullah University of Science and Technology
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

## Run a job
## $1 : diffraction data file (.cif or .mtz)
## $2 : list of contaminants to test (optional txt file) (default is all)

# Exit on error
set -e
abort () {
    printf "[FAILED]\n"
    exit 1
}
trap 'abort' EXIT

printf "Checking environment and input... "
# Check CM_PATH in env
if [ -z "$CM_PATH" ] || [ ! -d "$CM_PATH" ]
then
    printf "\nMissing CM_PATH in env.\n" >&2
    exit 1
fi

# Check ContaBase is complete
contabase_dir="$CM_PATH/data/contabase"
status="$CM_PATH/scripts/status.sh"
# shellcheck source=status.sh
. "$status" > /dev/null
if ! is_prepared "$contabase_dir"
then
    printf "\nWarning: ContaBase is not ready. " >&2
    printf "Some contaminants may not be tested. " >&2
fi

# Source MoRDa and CCP4 paths
define_paths="$CM_PATH/scripts/define_paths.sh"
if [ ! -f "$define_paths" ]
then
    printf "\nError: Installation seems corrupted. " >&2
    printf "Please re-install ContaMiner.\n" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$define_paths"
# shellcheck source=/dev/null
. "$SOURCE1"
# shellcheck source=/dev/null
. "$SOURCE2"
# shellcheck source=/dev/null
. "$SOURCE3"

# Load tools
# shellcheck source=xmltools.sh
. "$CM_PATH/scripts/xmltools.sh"
# shellcheck source=convert.sh
. "$CM_PATH/scripts/convert.sh"
# shellcheck source=mtztools.sh
. "$CM_PATH/scripts/mtztools.sh"
# shellcheck source=list_tasks.sh
. "$CM_PATH/scripts/list_tasks.sh"

# Check input
if [ $# -lt 1 ] || printf "%s" "$1" | grep -vq ".*\.\(mtz\|cif\)"
then
    printf "\nMissing arguments\n" >&2
    exit 1
fi
if [ ! -f "$1" ]
then
    printf "\nFile %s does not exist.\n" "$1" >&2
    exit 1
fi
if [ $# -ge 2 ] && [ -n "$2" ] && [ ! -f "$2" ]
then
    printf "\nFile %s does not exist.\n" "$2" >&2
    exit 1
fi
printf "[OK]\n"

# Select contaminants
printf "Selecting contaminants..."
contabase="$CM_PATH/init/contabase.xml"
contaminants_list=""
if [ $# -ge 2 ] && [ -n "$2" ]
then
    contaminants_list="$(grep -v "^#" "$2" | grep -v "^ *$")"
else
    contaminants_list="$(
        getXpath "//category[default='true']/contaminant/uniprot_id/text()" \
            "$contabase"
        )"
fi
printf "[OK]\n"

# Prepare environment
printf "Preparing environment... "
# Create work_dir
work_dir=$(basename "$1" | sed -r 's/\.mtz|\.cif//')
mkdir "$work_dir" 2>/dev/null

# Copy files in work dir
cp "$1" "$work_dir"
input_file_name=$(readlink -f "$work_dir/$(basename "$1")")
if [ $# -ge 2 ]
then
    cp "$2" "$work_dir"
    list_file_name=$(readlink -f "$work_dir/$(basename "$2")")
fi
contaminants_ids="$(clean_contaminants "$contaminants_list" "$work_dir")"
printf "[OK]\n"

# Convert file to mtz if applicable
if ! checkMtz "$input_file_name"
then
    printf "Converting file to MTZ... "
    safeToMtz "$input_file_name"
    printf "[OK]\n"
fi
mtz_filename=$(printf "%s" "$input_file_name" | sed 's/\.cif$/\.mtz/')

# Select alternative space group
printf "Selecting alternative space groups... "
alt_space_groups="$(get_alternate_space_groups "$mtz_filename")"
printf "[OK]\n"

# Create results.txt file
printf "Creating list of tasks... "
results_file="$work_dir/results.txt"
results_content "$contaminants_ids" "$alt_space_groups" > "$results_file"
printf "[OK]\n"

printf "Submitting job to SLURM... "
cd "$work_dir"
sbatch --array=1-$(wc -l < "$results_file") \
       "$CM_PATH/scripts/CM_solve.slurm" \
       "$input_file_name" > /dev/null
printf "[OK]\n"

# Do not execute abort() if exit here
trap EXIT
