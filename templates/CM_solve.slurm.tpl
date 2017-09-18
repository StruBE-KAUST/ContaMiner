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

## $1 : MTZ file
## env must contain CM_PATH
## current_path must contain the input MTZ file and the results.txt file
## must be submitted as a step of a job array

## sbatch script to run MoRDa and parse the result

## SBATCH options
## START
## END

# Exit on error
set -e
abort () {
    printf "Failure, exiting\n" >&2
    printf "Trying to update results file\n" >&2
    if [ ! -z "$1" ] && [ ! -z "$2" ]
    then
        results_file="$1"
        task_id="$2"
        lock_file="${results_file}.lock"
        # Lock #####################################
        lockfile -r-1 "$lock_file"                 #
        sed -i "/$task_id,/c\\$task_id,error,0,0,$elaps_time" "$results_file"
        rm -f "$lock_file"                         #
        ############################################
    fi
    exit 1
}
results_file=""
task_id=""
trap 'abort "$results_file" "$task_id"' EXIT

# Source MoRDa and CCP4 paths
define_paths="$CM_PATH/scripts/define_paths.sh"
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
# shellcheck source=../scripts/xmltools.sh
. "$xml_tools"

# Load conversion tools
convert_path="$CM_PATH/scripts/convert.sh"
# shellcheck source=../scripts/convert.sh
. "$convert_path"

mtz_file_name=$(readlink -f "$1")
results_file=$(readlink -f "results.txt")

task_id=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$results_file" \
              | cut --delimiter=',' -f-3)

first_arg=$(printf "%s" "$task_id" | cut --delimiter=',' -f1)
case $first_arg in
    c_*)
        # Custom contaminant
        contaminant_id="$(printf "%s" "$(basename "$first_arg")")"
	model_dir="$(readlink -f "$first_arg")"
	;;
    *)
	# ContaBase contaminant
	contaminant_id="$first_arg"
	model_dir="$CM_PATH/data/contabase/$contaminant_id/models"
	;;
esac
pack_number=$(printf "%s" "$task_id" | cut --delimiter=',' -f2)
alt_sg_slug=$(printf "%s" "$task_id" | cut --delimiter=',' -f3)
alt_sg=$(printf "%s" "$alt_sg_slug" | sed 's/-/ /g')
work_dir="${contaminant_id}_${pack_number}_${alt_sg_slug}"
mkdir -p "$work_dir"

output_dir=$(readlink -f "$work_dir")
resdir="$output_dir/results_solve"
outdir="$output_dir/out_solve"
scrdir="$output_dir/scr_solve"

cd "$output_dir"

# Define timeout
slurm_time=$(squeue -j "$SLURM_JOBID" -h -o "%l" | head -n 1)
days_limit=$(echo "$slurm_time" | cut --delimiter="-" -sf1)
field1=$(echo "$slurm_time" | cut --delimiter=":" -sf1)
field2=$(echo "$slurm_time" | cut --delimiter=":" -sf2)
field3=$(echo "$slurm_time" | cut --delimiter=":" -sf3)

if [ -z "$field3" ]
then
    if [ -z "$field2" ]
    then
        timeout=$field1
    else
        timeout=$(( field1 * 60 + field2 ))
    fi
else
    timeout=$(( field1 * 3600 + field2 * 60 + field3 ))
fi
# Add days
if [ -n "$days_limit" ]
then
    timeout=$(( timeout + days_limit *24*3600 ))
fi

# We remove 10 mn to be sure we have enough time to run the final steps
timeout=$(( timeout - 600 ))

# Delay the start of the job to avoid I/O overload
random=$( head -c1 /dev/random | od -viA n | tr -d "[:blank:]")
sleep "$random"

# Core job
morda_solve \
    -f  "$mtz_file_name" \
    -m  "$model_dir" \
    -p  "$pack_number" \
    -sg "$alt_sg" \
    -r  "$resdir" \
    -po "$outdir" \
    -ps "$scrdir" &
job_PID=$!

# Run a watchdog to stop the job before slurm time limit
{
    sleep $timeout
    kill -9 $job_PID
    printf "Abort\n"
}& > /dev/null 2>&1
watchdog_PID=$!

# Wait for the watchdog to timeout and kill the job, or the job to terminate.
wait $job_PID > /dev/null 2>&1
sleep 1 # Avoid killing watchdog while it's finishing
kill -9 $watchdog_PID > /dev/null 2>&1

# exit_status is 1 if the watchdog terminated before being killed
# ie : job is aborted
exit_status=$?

# Parse result
lock_file="${results_file}.lock"
if [ $exit_status -eq 1 ] # job has been aborted
then
    elaps_time=$(date -u -d @$timeo ut +"%Hh %2Mm %2Ss")
# Lock #####################################
    lockfile -r-1 "$lock_file"             #
    sed -i "/$task_id,/c\\$task_id,aborted,0,0,$elaps_time" "$results_file"
    rm -f "$lock_file"                     #
############################################
else
    xml_file=$resdir"/morda_solve.xml"
    log_file=$resdir"/morda_solve.log"
    err=$(getXpath "//err_level/text()" "$xml_file")
    elaps_time=$(grep "Elapsed: " "$log_file" \
        | tail -n 1 \
        | cut --delimiter=":" -f 3 \
        | tr -d '\n' \
        | sed 's/^\ *//g' \
        )
    case $err in
    7)
# Lock #####################################
        lockfile -r-1 "$lock_file"         #
        sed -i "/$task_id,/c\\$task_id,completed,0,0,$elaps_time" "$results_file"
        rm -f "$lock_file"                 #
############################################
        ;;
    0)
        # xmllpath outdated, no support of --xpath option...
        q_factor=$(getXpath "//q_factor/text()" "$xml_file")
        percent=$(getXpath "//percent/text()" "$xml_file")

        newline="completed,$q_factor,$percent,$elaps_time"
# Lock #####################################
        lockfile -r-1 "$lock_file"         #
        sed -i "/$task_id,/c\\$task_id,$newline" "$results_file"
        rm -f "$lock_file"                 #
############################################

        # Convert MTZ file to MAP
        mtz_filename="$resdir/final.mtz"
        mtz2map "$mtz_filename"

        # If positive result and contaminant from ContaBase
        if [ "$percent" -ge 99 ] && echo "$task_id" | grep -q "^[A-Z]"
        then
            # Increase score for this contaminant, model and space group
            ml_scores_file="$CM_PATH/data/ml_scores.xml"
            contaminant_old_score=$(getXpath \
                "//contaminant[uniprot_id='$contaminant_id']/score/text()" \
                "$ml_scores_file" \
                )
            contaminant_score=$(( contaminant_old_score + 1 ))
            setXpath "//contaminant[uniprot_id='$contaminant_id']/score" \
                $contaminant_score "$ml_scores_file"

            packs_file="$CM_PATH/data/contabase/$contaminant_id/packs"
            pack_old_score=$( \
                grep "$pack_number:" "$packs_file" \
                | cut --delimiter=':' -f 2 \
                | tail -n 1 \
                )
            pack_score=$(( pack_old_score + 1 ))
            sed -i "s/$pack_number:.*/$pack_number:$pack_score/" "$packs_file"

            sg_old_score=$(getXpath \
                "//space_group[name='$alt_sg']/score/text()" \
                "$ml_scores_file" \
                )
            sg_score=$(( sg_old_score + 1 ))
            setXpath "//space_group[name='$alt_sg']/score" \
                $sg_score "$ml_scores_file"
        fi
        ;;
    *)
# Lock #####################################
        lockfile -r-1 "$lock_file"         #
        sed -i "/$task_id,/c\\$task_id,error,0,0,$elaps_time" "$results_file"
        rm -f "$lock_file"                 #
############################################
        ;;
    esac
fi

# Do not execute abort() if exit here
trap - EXIT
