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

## Download the fasta files associated to the contaminants.txt file
## Then run morda_prep for each contaminant.

# Change to POSIX mode
{
    # shellcheck source=../scripts/posix_mode.sh
    . "scripts/posix_mode.sh"
} || {
    printf "Directory seems corrupted. Please check.\n"
    exit 1
}

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

# Init machine learning scores
init_scores="$cm_path/init/ml_scores.xml"
data_scores="$cm_path/data/ml_scores.xml"
if [ ! -f "$data_scores" ]
then
    {
        cp -T "$init_scores" "$data_scores"
    } || {
        printf "Unable to copy %s to %s." "$init_scores" "$data_scores" >&2
        exit 1
    }
fi

printf "Downloading fasta sequences... "
# Define download function
download_path="$cm_path/scripts/download.sh"
# shellcheck source=download.sh
. "$download_path"
export -f fasta_download

# Load XML tools
xml_tools="$CM_PATH/scripts/xmltools.sh"
# shellcheck source=xmltools.sh
. "$xml_tools"

# See <a href="https://github.com/koalaman/shellcheck/wiki/SC2039"></a>
IFS="$(printf '%b_' '\n')"; IFS="${IFS%_}"

# shellcheck disable=SC2016
for ID in $(getXpath "//contaminant/uniprot_id/text()" "$contabase")
do
    printf "%s\n" "$ID"
    printf "%s\n" "$contabase_dir"
done | xargs -n 2 -P 0 sh -c 'fasta_download "$0" "$1"'
printf "[OK]\n"

# Check availability of morda_prep
#shellcheck source=/dev/null
. "$SOURCE1"
#shellcheck source=/dev/null
. "$SOURCE2"
#shellcheck source=/dev/null
. "$SOURCE3"
morda_prep -h > /dev/null 2>&1
if [ $? -eq 127 ]
then
    printf "morda_prep not found. Please check your installation.\n"
    exit 1
fi

# Submit prep jobs
nb_contaminants_submitted=0
cd "$contabase_dir" || \
    (printf "\n%s does not exist." "$contabase_dir" && exit 1)

for ID in $(getXpath "//contaminant/uniprot_id/text()" "$contabase")
do
    if [ -n "$ID" ]
    then
        ID=$(printf "%s" "$ID" | tr -d "\r\n ")
        exact_model=$(\
            getXpath "//contaminant[uniprot_id='$ID']/exact_model/text()" \
                "$contabase")
        nb_homologues=0
        if [ "$exact_model" = "true" ]
        then
            nb_homologues=1
        else
            nb_homologues=3
        fi

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
            printf "%s: Submission to SLURM... " "$ID"
            touch "$ID/packs"
            {
                sbatch "$cm_path/scripts/CM_prep.slurm" \
                    "$ID" "$nb_homologues" > /dev/null
            } || {
                printf "Error: Unable to submit batch job to prepare %s."\
                    "$ID" >&2
                exit 1
            }
            nb_contaminants_submitted=$(( nb_contaminants_submitted + 1 ))
            printf "[OK]\n"
        fi

        contaminant_score=$(\
            getXpath "//contaminant[uniprot_id='$ID']/score/text()" \
                "$data_scores")
        if [ -z "$contaminant_score" ]
        then
            str_to_ins1='\        <contaminant>\n'
            str_to_ins2='            <uniprot_id>'$ID'<\/uniprot_id>\n'
            str_to_ins3='            <score>1<\/score>\n'
            str_to_ins4='        <\/contaminant>\n    <\/contaminants>'
            str_to_ins=$str_to_ins1$str_to_ins2$str_to_ins3$str_to_ins4
            sed -i "/<\/contaminants>/c$str_to_ins" "$data_scores"
        fi
    fi
done

printf "Number of contaminants submitted for preparation: %s\n" \
    "$nb_contaminants_submitted"

printf "Wait for the preparation to be complete before submitting a job.\n"
printf "You can check the ContaMiner status by using ./contaminer status.\n"
