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

# TODO: Error on lockfile must stop the script

# Check CM_PATH in env
if [ -z "$CM_PATH" ] || [ ! -d "$CM_PATH" ]
then
    printf "Missing CM_PATH in env.\n" >&2
    exit 1
fi

# Check ContaBase is complete
contabase_dir="$CM_PATH/data/contabase"
status="$CM_PATH/scripts/status.sh"
# shellcheck source=status.sh
. "$status" > /dev/null
if ! is_prepared "$contabase_dir"
then
    printf "Warning: ContaBase is not ready. " >&2
    printf "Some contaminants may not be tested.\n" >&2
fi


# Source MoRDa and CCP4 paths
define_paths="$CM_PATH/scripts/define_paths.sh"
if [ ! -f "$define_paths" ]
then
    printf "Error: Installation seems corrupted. " >&2
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

# Load XML tools
xml_tools="$CM_PATH/scripts/xmltools.sh"
# shellcheck source=xmltools.sh
. "$xml_tools"

# Check input
if [ $# -lt 1 ] || printf "%s" "$1" | grep -vq ".*\.\(mtz\|cif\)"
then
    printf "Missing arguments\n" >&2
    exit 1
fi
if [ ! -f "$1" ]
then
    printf "File %s does not exist.\n" "$1" >&2
    exit 1
fi
if [ $# -ge 2 ] && [ -n "$2" ] && [ ! -f "$2" ]
then
    printf "File %s does not exist.\n" "$2" >&2
    exit 1
fi

# Prepare environment
printf "Preparing environment... "
# Create work_dir
work_dir=$(basename "$1" | sed -r 's/\.mtz|\.cif//')
{
    mkdir "$work_dir"
} || {
    printf "Unable to create directory : %s\n" "$work_dir" >&2
    exit 1
}
cp "$1" "$work_dir"
input_file_name=$(readlink -f "$work_dir/$(basename "$1")")
if [ $# -ge 2 ]
then
    cp "$2" "$work_dir"
    list_file_name=$(readlink -f "$work_dir/$(basename "$2")")
fi
{
    cd "$work_dir"
} || {
    printf "%s does not exist." "$work_dir"
    exit 1
}
result_file="results.txt"
printf "" > "$result_file"
printf "[OK]\n"

# Convert file to mtz if applicable
# shellcheck source=../scripts/convert.sh
. "$CM_PATH/scripts/convert.sh"
if ! checkMtz "$input_file_name"
then
    printf "Converting file to MTZ... "
    {
        safeToMtz "$input_file_name"
    } || {
        printf "[FAILED]\n"
        exit 1
    }
    printf "[OK]\n"
fi
mtz_file_name=$(printf "%s" "$input_file_name" | sed 's/\.cif$/\.mtz/')

# Select alternative space group
printf "Selecting alternative space groups... "
# Current space group
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

# Select contaminants
printf "Selecting contaminants..."
contabase="$CM_PATH/init/contabase.xml"
contaminants_list=""
if [ $# -ge 2 ] && [ -n "$2" ]
then
    contaminants_list="$(cat "$list_file_name")"
else
    contaminants_list="$(
        getXpath "//category[default='true']/contaminant/uniprot_id/text()" \
            "$contabase"
        )"
fi
printf "[OK]\n"

# Submit solving jobs
printf "Submitting jobs to SLURM... "
ml_scores="$CM_PATH/data/ml_scores.xml"
## First loop to generate variables
printf "%s\n" "$contaminants_list" \
    | while IFS= read -r contaminant_id
do
    case $contaminant_id in
        /*|./*)
	    # Custom contaminant
	    # Check if custom file exists
	    if [ -f "$contaminant_id" ]
	    then
		# Create the custom models dir
		model_dir="$(echo "$contaminant_id" | cut --delimiter="." -f1)"
		mkdir -p "$model_dir"
		cp "$contaminant_id" "$model_dir/custom.pdb"
		cp "$CM_PATH/templates/model_prep.xml" "$model_dir"

		# Create task
		contaminant_score=1
		pack=1
		pack_score=1
		printf "%b" "$alt_space_groups" \
		    | while IFS= read -r alt_sg
		do
		    alt_sg_slug=$(printf "%s" "$alt_sg" | sed "s/ /-/g")
		    task_id="${model_dir},${pack},${alt_sg_slug}"
		    sg_score=$( \
			getXpath "//space_group[name='$alt_sg']/score/text()" \
			"$ml_scores" \
			)
		    task_score=$(( contaminant_score * pack_score * sg_score ))
		    printf "%s,%s\n" "$task_id" "$task_score"
		done
	    else
		printf "Warning: %s does not exist." "$contaminant_id" >&2
	    fi
	    ;;
	*)
	    # ContaBase contaminant
            contaminant_score=$( \
		getXpath "//contaminant[uniprot_id=$contaminant_id]/score/text()" \
		"$ml_scores" \
		)
            grep -v '^ *#' < "$contabase_dir/$contaminant_id/packs" \
		| grep -v '^$' \
		| while IFS= read -r pack_line
            do
		pack=$(printf "%s" "$pack_line" | cut --delimiter=':' -f1)
		pack_score=$(printf "%s" "$pack_line" | cut --delimiter=':' -f2)
		printf "%b" "$alt_space_groups" \
                    | while IFS= read -r alt_sg
		do
                    alt_sg_slug=$(printf "%s" "$alt_sg" | sed "s/ /-/g")
                    task_id="${contaminant_id},${pack},${alt_sg_slug}"
                    sg_score=$( \
			getXpath "//space_group[name='$alt_sg']/score/text()" \
                        "$ml_scores" \
                        )
                    task_score=$(( contaminant_score * pack_score * sg_score ))
                    printf "%s,%s\n" "$task_id" "$task_score"
		done
            done
	    ;;
    esac
## Then sort according to the score
## Then submit the jobs 
done | sort -rk 4 -t ',' -g \
    | while IFS= read -r line
do
    taskid=$(printf "%s" "$line" | cut --delimiter=',' -f1-3)
    printf "%s:cancelled:0h 00m 00s\n" "$taskid" >> "$result_file"
done

{
    sbatch --array=1-$(wc -l < "$result_file") \
        "$CM_PATH/scripts/CM_solve.slurm" \
        "$input_file_name" > /dev/null
    printf "[OK]\n"
} || {
    printf "[FAIL]\n"
}
