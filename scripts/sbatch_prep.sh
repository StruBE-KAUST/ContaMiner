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
##
## sbatch_init.sh version 1.0.0
## sbatch script to run morda_prep

#SBATCH --time=05:00:00
#SBATCH --ntasks=1
#SBATCH --quiet
#SBATCH --requeue

# Prepare environment
base_dir=$(pwd)
contam="$4"
struct_file="$5"
nb_homo=$6
fasta_file="$contam.fasta"
cd "$contam"

# Load MoRDa
. $1
. $2
. $3

# Core job
morda_prep -s $fasta_file -f $struct_file -alt -n $nb_homo

# Parse result
nbpacks=$(cat "out_prep/pack_info.xml" | \
sed -n "s/.*<n_pack> *\([0-9]\+\) *<\/n_pack>/\1/p" | tail -n 1)

printf "$nbpacks" > nbpacks

# Clean environment
find . -mindepth 1 -maxdepth 1 \
    \( ! -name models -and ! -name *.fasta -and ! -name nbpacks \) \
    -exec rm -r {} \;

xml_file="models/model_prep.xml"
sed -i 's,<nmon> \+[0-9]\+ </nmon>,<nmon>     0 </nmon>,g' $xml_file
