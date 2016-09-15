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

## sbatch script to run morda_prep

## SBATCH options
## START
## END

# Prepare environment
contam="$1"
struct_file="$2"
nb_homo=$3
fasta_file="$contam.fasta"
cd "$contam" || exit 1
model_score=$4

# Load MoRDa
# shellcheck source=/dev/null
. "$SOURCE1"
# shellcheck source=/dev/null
. "$SOURCE2"
# shellcheck source=/dev/null
. "$SOURCE3"

# Delay the start of the job to avoid I/O overload
random=$( head -c1 /dev/random | od -viA n | tr -d "[:blank:]")
sleep "$random"

# Core job
morda_prep -s "$fasta_file" -f "$struct_file" -alt -n "$nb_homo"

# Parse result
nbpacks=$(sed -n "s/.*<n_pack> *\([0-9]\+\) *<\/n_pack>/\1/p" "out_prep/pack_info.xml" | tail -n 1)

printf "" > nbpacks
for i in $(seq "$nbpacks")
do
    printf "%s:%s\n" "$i" "$model_score">> nbpacks
done

# Clean environment
find . -mindepth 1 -maxdepth 1 \
    \( ! -name models -and ! -name nbpacks -and ! -name -- "*.fasta"\) \
    -exec rm -r {} \;

xml_file="models/model_prep.xml"
sed -i 's,<nmon> \+[0-9]\+ </nmon>,<nmon>     0 </nmon>,g' $xml_file
