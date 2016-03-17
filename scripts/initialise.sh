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

## initialise.sh version 1.0.1
## Download the fasta files associated to the contaminants.txt file
## Then run morda_prep for each contaminant.

# Retrieve paths
if [ -z "$define_paths" ]
then
    printf "Do not use this script. "
    printf "Please run install.sh in the root directory.\n"
    exit 1
fi
. $define_paths

if [ ! -f "$contam_init_file" ]
then
    printf "The list of contaminants does not exist. "
    printf "Please check your installation.\n"
    exit 1
fi

# Prepare environment
mkdir -p $contam_path

printf "Downloading fasta sequences... "

# Define download function
. $scripts_path/download.sh
export -f fasta_download

# Download fasta files
for line in `cat "$contam_init_file"`
do
    printf "$line\n" | cut --delimiter=':' -f 1
    printf "$contam_path\n"
    printf "$init_path\n"
done | xargs -n 3 -P 0 sh -c 'fasta_download "$0" "$1" "$2"'
printf "[OK]\n"

# Download large structure
printf "Downloading a big structure file... "
if [ ! -f "$big_struct_cif" ]
then
    wget -q "http://www.rcsb.org/pdb/download/downloadFile.do?\
fileFormat=structfact&structureId=4Y4O" -O "$big_struct_cif"
fi
printf "[OK]\n"

# Check avalability of morda_prep
morda_prep -h > /dev/null 2>&1
if [ $? -eq 127 ]
then
    printf "morda_prep not found. Something went wrong.\n"
    printf "Please check your installation.\n"
    exit 1
fi

# Submit prep jobs
printf "Submitting preparation jobs to SLURM... "
cd "$contam_path"
for line in `cat "$contam_init_file"`
do
    contam=$(printf $line | cut --delimiter=':' -f 1)
    nb_homo=$(printf $line | cut --delimiter=':' -f 2)

    fasta_file=$contam".fasta"
    if [ ! -f "$contam/$fasta_file" ]
    then
        printf "$contam : fasta file does not exist. Re-run the installation.\n"
        exit 1
    fi

    if [ -f "$contam/nbpacks" ]
    then
        printf "$contam seems to be prepared already. Skipping...\n"
    else
        touch "$contam/nbpacks"
        sbatch $scripts_path"/sbatch_prep.sh" "$source1" "$source2" "$source3" \
        "$contam" "$big_struct_cif" "$nb_homo" > /dev/null
    fi
done
printf "[OK]\n"
