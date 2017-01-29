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

## sbatch script to run morda_prep
## Parameters :
## $1 : UniProt ID of the contaminant to prepare
## $2 : Number of homologues to prepare (n arg of morda_prep)
## env should contain SOURCE[1-3] to load CCP4 and MoRDa
## env should contain CM_PATH which is the path to the root directory of
## ContaMiner

## SBATCH options
## START
## END

# Change to POSIX mode
posix_mode="$CM_PATH/scripts/posix_mode.sh"
# shellcheck source=../scripts/posix_mode.sh
. "$posix_mode"

# Prepare environment
contaminant_id="$1"
nb_homologues="$2"
{
    cd "$contaminant_id"
} || {
    printf "%s directory does not exist." "$contaminant_id" >&2
    exit 1
}

# Load MoRDa
# shellcheck source=/dev/null
. "$SOURCE1"
# shellcheck source=/dev/null
. "$SOURCE2"
# shellcheck source=/dev/null
. "$SOURCE3"

# Load other tools
xml_tools="$CM_PATH/scripts/xmltools.sh"
# shellcheck source=../scripts/xmltools.sh
. "$xml_tools"

# Delay the start of the job to avoid I/O overload
random=$( head -c1 /dev/random | od -viA n | tr -d "[:blank:]")
sleep "$random"

# Core job
fasta_file="$contaminant_id.fasta"
{
    morda_prep -s "$fasta_file" -n "$nb_homologues"
} || {
    printf "Error: morda_prep failed for contaminant %s" "$contaminant_id" >&2
    exit 1
}

# Parse morda_prep.xml to find nbpacks
xml_file="models/model_prep.xml"
nbpacks=0

# See <a href="https://github.com/koalaman/shellcheck/wiki/SC2039">
IFS="$(printf '%b_' '\n')"; IFS="${IFS%_}"

for domain in $(getXpath "//domain/text()" "$xml_file")
do
    if [ "$domain" -eq 0 ] || [ "$domain" -eq 1 ]
    then
        nbpacks=$(( nbpacks + 1 ))
    fi
done

printf "" > packs
for i in $(seq "$nbpacks")
do
    printf "%s:%s\n" "$i" "$contaminant_score">> packs
done

# Clean environment
find . -mindepth 1 -maxdepth 1 \
    ! -name models -and ! -name packs -and ! -name "*.fasta" \
    -exec rm -r {} \;
rm -f "../slurm-$SLURM_JOBID.out"
