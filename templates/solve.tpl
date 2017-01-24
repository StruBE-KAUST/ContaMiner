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
printf "" > "$result_file"
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
alt_space_groups=$(printf "%b" "$alt_sg_commands" | alt_sg_list)
alt_space_groups=$(printf "%s" "$alt_space_groups" | 
    tr -d '\n' | 
    sed 's/.*-->\ *\(1.*\)/\1/' |
    sed 's/"\ *[0-9]\ *"/\n/g' | 
    sed 's/"$//' | sed 's/1\ *"//')
# POSIX rule : TXT files must end with \n
alt_space_groups="$alt_space_groups\n"
printf "[OK]\n"

# Submit solving jobs
printf "Creating list of jobs... "
contabase="$CM_PATH/data/contabase"
sg_scores_file="$CM_PATH/data/sg_scores.txt"
mkfifo tasks_list
mkfifo contaminants_list
grep -v '^ *#' < "$list_file" | grep -v '^$' > contaminants_list &
while IFS= read -r line
do
    # clean line
    contaminant_id=$(printf "%s" "$line" \
        | cut --delimiter=':' -f1\
        | cut --delimiter='#' -f1\
        | tr -d "[:blank:]")

    mkfifo packs_list
    grep -v '^ *#' < "$contabase/$contaminant_id/packs" \
        | grep -v '^$' > packs_list &
    while IFS= read -r pack_line
    do
        pack=$(printf "%s" "$pack_line" | cut --delimiter=':' -f1)
        pack_score=$(printf "%s" "$pack_line" | cut --delimiter=':' -f2)
        printf "%b" "$alt_space_groups" | while IFS= read -r alt_sg
        do
            alt_sg_slug=$(printf "%s" "$alt_sg" | sed "s/ /-/g")
            task_id="${contaminant_id}_${pack}_${alt_sg_slug}"
            sg_score=$(grep "$alt_sg:" "$sg_scores_file" |\
                cut --delimiter=':' -f2 | tail -n 1)
            if [ -z "$sg_score" ]
            then
                sg_score=0
            fi
            task_score=$(( pack_score * sg_score ))
            printf "%s_%s\n" "$task_id" "$task_score" > tasks_list &
        done
    done < packs_list
    rm packs_list
done < contaminants_list
rm contaminants_list
printf "[OK]\n"

printf "Sorting tasks... "
mkfifo tasks_list_sorted
sort -rk 4 -t '_' -g < tasks_list > tasks_list_sorted &
printf "[OK]\n"

printf "Submitting jobs to SLURM... "
while IFS= read -r line
do
    contaminant=$(printf "%s" "$line" | cut --delimiter='_' -f1)
    pack=$(printf "%s" "$line" | cut --delimiter='_' -f2)
    alt_sg_slug=$(printf "%s" "$line" | cut --delimiter='_' -f3)
    alt_sg=$(printf "%s" "$alt_sg_slug" | sed "s/-/ /g")
    taskid=$(printf "%s" "$line" | cut --delimiter='_' -f1-3)
    printf "%s:cancelled:0h 00m 00s\n" "$taskid" >> "$result_file"
    sbatch "$CM_PATH/scripts/CM_solve.slurm" \
        "$contaminant" "$mtz_file_name" "$pack" "$alt_sg" > /dev/null
done < tasks_list_sorted
rm tasks_list
rm tasks_list_sorted
printf "[OK]\n"
