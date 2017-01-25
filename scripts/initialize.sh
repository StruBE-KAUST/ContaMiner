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

## Download the fasta files associated to the contaminants.txt file
## Then run morda_prep for each contaminant.

# Source MoRDa and CCP4 paths
cm_path="$(dirname "$(dirname "$(readlink -f "$0")")")"
define_paths="$cm_path/scripts/define_paths.sh"
if [ ! -f "$define_paths" ]
then
    printf "Error: Installation seems corrupted. " >&2
    printf "Please re-install ContaMiner.\n" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$define_paths"

# Check the contabase.txt file
contabase="$cm_path/init/contabase.xml"
if [ ! -f "$contabase" ]
then
    printf "The list of contaminants does not exist. "
    printf "Please check your installation.\n"
    exit 1
fi

# Prepare environment
contabase_dir="$cm_path/data/contabase"
mkdir -p "$contabase_dir"
export SOURCE1
export SOURCE2
export SOURCE3
CM_PATH="$cm_path"
export CM_PATH

printf "Downloading fasta sequences... "
# Define download function
download_path="$cm_path/scripts/download.sh"
# shellcheck source=download.sh
. "$download_path"
export -f fasta_download

# Download fasta files
init_dir="$cm_path/init"
# shellcheck disable=SC2016
printf "cat //contaminant/uniprot_id/text()\n" \
    | xmllint --shell "$contabase" \
    | grep -v "/ >" \
    | grep -v "-" \
    | while IFS='-' read -r ID
do
    if [ -n "$ID" ]
    then
        ID=$(printf "%s" "$ID" | tr -d "\r\n ")
        printf "%s\n" "$ID"
        printf "%s\n" "$contabase_dir"
        printf "%s\n" "$init_dir"
    fi
done | xargs -n 3 -P 0 sh -c 'fasta_download "$0" "$1" "$2"'
printf "[OK]\n"

# Check availability of morda_prep
morda_prep -h > /dev/null 2>&1
if [ $? -eq 127 ]
then
    printf "morda_prep not found. Please check your installation.\n"
    exit 1
fi

# Submit prep jobs
printf "Submitting preparation jobs to SLURM... "
cd "$contabase_dir" || \
    (printf "\n%s does not exist." "$contabase_dir" && exit 1)
printf "cat //contaminant/uniprot_id/text()\n" \
    | xmllint --shell "$contabase" \
    | grep -v "/ >" \
    | grep -v "-" \
    | while IFS='-' read -r ID
do
    if [ -n "$ID" ]
    then
        ID=$(printf "%s" "$ID" | tr -d "\r\n ")
        exact_model=$(\
            printf "cat //contaminant[uniprot_id='%s']/exact_model/text()" \
                "$ID" \
                | xmllint --shell "$contabase" \
                | grep -v "/ >")
        nb_homologues=0
        if [ "$exact_model" = "true" ]
        then
            nb_homologues=1
        else
            nb_homologues=3
        fi
        contaminant_score=1

        fasta_file=$ID".fasta"
        if [ ! -f "$ID/$fasta_file" ]
        then
            printf "%s : fasta file does not exist. " "$ID"
            printf "Please re-run the initialization.\n"
            exit 1
        fi

        if [ ! -f "$ID/packs" ]
        then
            # Presence of this file means the preparation is done, or in progress
            printf "%s : preparation starting... " "$ID"
            touch "$ID/packs"
            sbatch "$cm_path/scripts/CM_prep.slurm" \
                "$ID" "$nb_homologues" "$contaminant_score" > /dev/null
            printf "[OK]\n"
        fi
    fi
done
printf "[OK]\n"

# Init space_groups scores
#cp "$init_path/sg_scores.txt" "$sg_scores_file"
