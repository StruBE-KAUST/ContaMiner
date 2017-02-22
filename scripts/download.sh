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

## Define the function to download a fasta file and store it in the correct
## location

# Parameters :
# $1 : uniprot_id
# $2 : location (create a directory inside the location)
fasta_download () {
    if [ $# -ne 2 ]
    then
        printf "Wrong number of arguments.\n"
        return 1
    fi

    uni_id=$(printf "%s" "$1" | tr "[:lower:]" "[:upper]")

    # Source xmltools
    xml_tools="$CM_PATH/scripts/xmltools.sh"
    # shellcheck source=xmltools.sh
    . "$xml_tools"

    mkdir -p "$2/$uni_id"

    if [ ! -f "$uni_id.fasta" ]
    then
        contabase="$CM_PATH/init/contabase.xml"
        sequence=$(getXpath \
            "//contaminant[uniprot_id='$uni_id']/sequence/text()" \
            "$contabase")
        if [ -n "$sequence" ]
        then
            printf "%s" "$sequence" > "$2/$uni_id/$uni_id.fasta"
        else
            fasta_url="http://www.uniprot.org/uniprot/$uni_id.fasta"
            wget -q "$fasta_url" -O "$2/$uni_id/$uni_id.fasta"
            if [ $? -ne 0 ]
            then
                printf "%s : error. Fasta file not downloaded.\n" "$uni_id"
            fi
        fi
    fi
}
