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

## $1 : Contaminant ID
## $2 : MTZ input filename
## $3 : pack #
## $4 : space_group
## env must contain CM_PATH, SOURCE1, SOURCE2, and SOURCE3
## current_path must contain the input MTZ file and the results.txt file

## sbatch script to run MoRDa and parse the result

## SBATCH options
## START
## END

# Prepare environment
# shellcheck source=/dev/null
. "$SOURCE1"
# shellcheck source=/dev/null
. "$SOURCE2"
# shellcheck source=/dev/null
. "$SOURCE3"


contaminant="$1"
input_file_name="$2"
res_file=$(readlink -f "results.txt")
pack="$3"
alt_sg="$4"
alt_sg_slug=$(printf "%s" "$alt_sg" | sed 's/ /-/g')
task_id="${contaminant}_${pack}_${alt_sg_slug}"
mkdir -p "$task_id"
output_dir=$(readlink -f "$task_id")
resdir="$output_dir/results_solve"
outdir="$output_dir/out_solve"
scrdir="$output_dir/scr_solve"
model_dir="$CM_PATH/data/contabase/$contaminant/models"
cd "$output_dir" || \
    (printf "%s does not exist." "$output_dir" && exit 1)

# Define timeout
slurm_time=$(squeue -j "$SLURM_JOBID" -h -o "%l")
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
    -f "$input_file_name" \
    -m "$model_dir" \
    -p "$pack" \
    -sg "$alt_sg" \
    -r "$resdir" \
    -po "$outdir" \
    -ps "$scrdir" &
job_PID=$!

# Run a watchdog to stop the job before slurm time limit
(sleep $timeout; kill -9 $job_PID; printf "Aborted") & 2>/dev/null
watchdog_PID=$!

# Wait for the watchdog to timeout and kill the job, or the job to terminate.
wait $job_PID
kill -9 $watchdog_PID

# exit_status is 1 if the watchdog terminated before being killed
# ie : job is aborted
exit_status=$?

# Parse result
xml_file=$resdir"/morda_solve.xml"
log_file=$resdir"/morda_solve.log"
err=$(grep "<err_level>" "$xml_file" | cut --delimiter=" " -f 8)
elaps_time=$(grep "Elapsed: " "$log_file" \
    | tail -n 1 \
    | cut --delimiter=":" -f 3 \
    | tr -d '\n' \
    | sed 's/^\ *//g' \
    )
lock_file="$res_file.lock"

if [ $exit_status -eq 1 ] # job has been aborted
then
    elaps_time=$(date -u -d @$timeout +"%Hh %2Mm %2Ss")
    lockfile -r-1 "$lock_file"
    sed -i "/$task_id:/c\\$task_id:aborted:$elaps_time" "$res_file"
    rm -f "$lock_file"
else
    case $err in
    7)
        lockfile -r-1 "$lock_file"
        sed -i "/$task_id:/c\\$task_id:nosolution:$elaps_time" "$res_file"
        rm -f "$lock_file"
        ;;
    0)
        # xmllpath outdated, no support of --xpath option...
        q_factor=$( \
            printf "cat //q_factor/text()\n" \
            | xmllint --shell "$xml_file" \
            | grep -v "/ >" \
            | tr -d "[:blank:]" \
            )

        percent=$( \
            printf "cat //percent/text()\n" \
            | xmllint --shell "$xml_file" \
            | grep -v "/ >" \
            | tr -d "[:blank:]" \
            )

        newline="$q_factor-$percent:$elaps_time"
        lockfile -r-1 "$lock_file"
        sed -i "/$task_id:/c\\$task_id:$newline" "$res_file"
        rm -f "$lock_file"

        # Remove all jobs for other contaminants if positive result
        if [ "$percent" -ge 90 ]
        then
            jobids=$( \
                squeue -u "$(whoami)" -o %A:%o \
                | grep "$input_file_name" \
                | cut --delimiter=":" -f1 \
                )
            if [ -n "$jobids" ]
            then
                scancel "$jobids"
            fi

            # Increase score for this model and space group
            packs_file="$CM_PATH/data/contabase/$contaminant/packs"
            old_score=$( \
                grep "$pack:" "$packs_file" \
                | cut --delimiter=':' -f 2 \
                | tail -n 1 \
                )
            new_score=$(( old_score + 1 ))
            sed -i "s/$pack:.*/$pack:$new_score/" "$packs_file"

            sg_scores_file="$CM_PATH/data/sg_scores.txt"
            old_score=$( \
                grep "$alt_sg:" "$sg_scores_file" \
                | cut --delimiter=':' -f 2 \
                | tail -n 1 \
                )
            new_score=$(( old_score + 1 ))
            sed -i "s/$alt_sg:.*/$alt_sg:$new_score/" "$sg_scores_file"
        fi
        ;;
    *)
        lockfile -r-1 "$lock_file"
        sed -i "/$task_id:/c\\$task_id:error:$elaps_time" "$res_file"
        rm -f "$lock_file"
        ;;
    esac
fi

# == 1 because current job is still running
if [ "$(squeue -u "$(whoami)" -o %o | grep -c "$input_file_name")" -eq 1 ]
then
    # job finished for this diffraction data file
    sh "$CM_PATH/finish.sh" "$(readlink -f "$res_file")"
fi
