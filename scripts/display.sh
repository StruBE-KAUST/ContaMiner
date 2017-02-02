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

## Print the whole ContaBase in XML format
## Load XML tools
xml_tools="$CM_PATH/scripts/xmltools.sh"
# shellcheck source=xmltools.sh
. "$xml_tools"

## Display prepared contaminants from the contabase
find "$CM_PATH/data/contabase" -maxdepth 1 -mindepth 1 -type d \
    | while IFS= read -r cont
do
    echo "<contaminant>"
    echo "  <uniprot_id>$cont</uniprot_id>"
    extractPacks "$cont/models/model_prep.xml"
    echo "</contaminant>"
done
