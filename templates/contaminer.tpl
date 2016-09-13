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

## Run a job
## $1 : diffraction data file (.cif or .mtz)
## $2 : list of contaminants to test (optional txt file)

set -e

define_paths=
export define_paths
. "$define_paths"

IFS='
'

# Check input
if [ $# -lt 1 ] || printf $1 | grep -vq ".*\.\(mtz\|cif\)"
then
	printf "Usage :\n"
	printf " $0 <file.mtz> | <file.cif> [file.txt]\n"
	exit 1
fi
if [ ! -f $1 ]
then
	printf "File $1 does not exist.\n"
	exit 1
fi
if [ $# -eq 2 ] && [ ! -f $2 ]
then
	printf "File $2 does not exist.\n"
    exit 1
fi

# Prepare environment
work_dir=$(basename "$1" | sed -r 's/\.mtz|\.cif//')
mkdir -p "$work_dir"
cp "$1" "$work_dir"
input_file_name=$(readlink -f "$work_dir/$(basename "$1")")
list_file_name=""
if [ $# -eq 2 ]
then
    cp "$2" "$work_dir"
    list_file_name=$(readlink -f "$work_dir/$(basename "$2")")
fi
cd "$work_dir"
result_file="results.txt"
tasks_file="tasks.txt"
printf "" > "$result_file"
printf "" > "$tasks_file"

# Convert file to mtz in case of
printf "Converting file... "
. "$scripts_path/convert.sh"
safe_convert "$input_file_name"
mtz_file_name=$(printf "$input_file_name" | sed 's/\.cif$/\.mtz/')
printf "[OK]\n"

# Determine space group
printf "Determining alternative space groups... "
space_group=$(mtzdmp "$mtz_file_name" | grep "Space group" | 
    sed "s/.*'\(.*\)'.*/\1/")
alt_sg_commands="N\nSG "$space_group"\n\n"
alt_space_groups=$(printf "$alt_sg_commands" | alt_sg_list)
alt_space_groups=$(printf "$alt_space_groups" | 
    tr -d '\n' | 
    sed 's/.*-->\ *\(1.*\)/\1/' |
    sed 's/"\ *[0-9]\ *"/\n/g' | 
    sed 's/"$//' | sed 's/1\ *"//')
printf "[OK]\n"

# Evaluate list of contaminants
if [ -z "$list_file_name" ]
then
    list_file_name="$contam_init_file"
fi

# Submit solving jobs
printf "Creating list of jobs... "
for contaminant in $(cat "$list_file_name" | cut --delimiter=':' -f 1)
do
    contam_file="$contam_path/$contaminant"
    for line in $(cat "$contam_file/nbpacks")
    do
        ipack=$(printf "$line" | cut --delimiter=':' -f 1)
        model_score=$(printf "$line" | cut --delimiter=':' -f 2)
        for alt_sg in $alt_space_groups
        do
            alt_sg_slug=$(printf $alt_sg | sed "s/ /-/g")
            taskid=$contaminant"_"$ipack"_"$alt_sg_slug
            sg_score=$(grep "$alt_sg:" "$sg_scores_file" |\
                cut --delimiter=':' -f 2 | tail -n 1)
            if [ -z "$sg_score" ]
            then
                sg_score=0
            fi
            score=$(( $model_score * $sg_score ))
            printf "$taskid" >> "$tasks_file"
            printf "_$score\n" >> "$tasks_file"
        done
    done
done
printf "[OK]\n"

printf "Submitting jobs to SLURM... "
for task in $(cat "$tasks_file" | sort -rk 4 -t '_')
do
    contaminant=$(printf "$task" | cut --delimiter='_' -f 1)
    ipack=$(printf "$task" | cut --delimiter='_' -f 2)
    alt_sg_slug=$(printf "$task" | cut --delimiter='_' -f 3)
    alt_sg=$(printf "$alt_sg_slug" | sed "s/-/ /g")
    taskid=$contaminant"_"$ipack"_"$alt_sg_slug
    printf "$taskid:cancelled:0h 00m 00s\n" >> "$result_file"
    sbatch "$scripts_path/sbatch_run.sh" "$define_paths" \
        "$contaminant" "$input_file_name" "$ipack" "$alt_sg" > /dev/null
done
printf "[OK]\n"