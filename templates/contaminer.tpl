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
## $2 : list of contaminants to test (optional txt file) (default is
## init/contabase.txt)

CM_PATH=
export CM_PATH

# shellcheck source=/dev/null
. "$CM_PATH/scripts/define_paths.sh"
export SOURCE1
export SOURCE2
export SOURCE3

# Check input
if [ $# -lt 1 ] || printf "%s" "$1" | grep -vq ".*\.\(mtz\|cif\)"
then
	printf "Usage :\n"
	printf " %s <file.mtz> | <file.cif> [file.txt]\n" "$0"
	exit 1
fi
if [ ! -f "$1" ]
then
	printf "File %s does not exist.\n" "$1"
	exit 1
fi
if [ $# -eq 2 ] && [ ! -f "$2" ]
then
	printf "File %s does not exist.\n" "$2"
    exit 1
fi

# Prepare environment
printf "Preparing environment... "
# Create work_dir or work_dir_0 or work_dir_1, ...
work_dir=$(basename "$1" | sed -r 's/\.mtz|\.cif//')
if ! mkdir "$work_dir" 2>/dev/null
then
    n=0
    while ! mkdir "${work_dir}_$n" 2>/dev/null
    do
        n=$((n+1))
    done
    work_dir="${work_dir}_$n"
fi
cp "$1" "$work_dir"
input_file_name=$(readlink -f "$work_dir/$(basename "$1")")
list_file="$CM_PATH/init/contabase.txt"
if [ $# -eq 2 ]
then
    cp "$2" "$work_dir"
    list_file=$(readlink -f "$work_dir/$(basename "$2")")
fi
cd "$work_dir" || \
    (printf "%s does not exist." "$work_dir" && exit 1)
result_file="results.txt"
tasks_file="tasks.txt"
printf "" > "$result_file"
printf "" > "$tasks_file"
printf "%s [OK]\n" "$work_dir"

# Convert file to mtz in case of
printf "Converting file to MTZ... "
# shellcheck source=../scripts/convert.sh
. "$CM_PATH/scripts/convert.sh"
safeToMtz "$input_file_name" || \
    (printf "[FAILED]\n" && exit 1)
mtz_file_name=$(printf "%s" "$input_file_name" | sed 's/\.cif$/\.mtz/')
printf "[OK]\n"

# Determine space group
printf "Determining alternative space groups... "
space_group=$(mtzdmp "$mtz_file_name" | grep "Space group" | 
    sed "s/.*'\(.*\)'.*/\1/")
alt_sg_commands="N\nSG $space_group\n\n"
alt_space_groups=$(printf "%s" "$alt_sg_commands" | alt_sg_list)
alt_space_groups=$(printf "%s" "$alt_space_groups" | 
    tr -d '\n' | 
    sed 's/.*-->\ *\(1.*\)/\1/' |
    sed 's/"\ *[0-9]\ *"/\n/g' | 
    sed 's/"$//' | sed 's/1\ *"//')
printf "[OK]\n"

# Submit solving jobs
printf "Creating list of jobs... "
contabase="$CM_PATH/data/contabase"
sg_scores_file="$CM_PATH/data/sg_scores.txt"
tasks_list=""
grep -v '^ *#' < "$list_file" | grep -v '^$' | while IFS= read -r line
do
    # clean line
    contaminant_id=$(printf "%s" "$line" \
        | cut --delimiter=':' -f1\
        | cut --delimiter='#' -f1\
        | tr -d "[:blank:]")

    grep -v '^ *#' < "$contabase/$contaminant_id/packs" \
        | grep -v '^$' |  while IFS= read -r pack
    do
        pack=$(printf "%s" "$pack" | cut --delimiter=':' -f1)
        pack_score=$(printf "$pack" | cut --delimiter=':' -f2)
        for alt_sg in $alt_space_groups
        do
            alt_sg_slug=$(printf "%s" "$alt_sg" | sed "s/ /-/g")
            taskid="${contaminant_id}_${ipack}_${alt_sg_slug}"
            sg_score=$(grep "$alt_sg:" "$sg_scores_file" |\
                cut --delimiter=':' -f2 | tail -n 1)
            if [ -z "$sg_score" ]
            then
                sg_score=0
            fi
            task_score=$(( $pack_score * $sg_score ))
            tasks_list="${tasks_list}\n${task_id}_${task_score}"
        done
    done
done
printf "[OK]\n"

printf "%s" "$tasks_list"

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
