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

contabase="$CM_PATH/init/contabase.xml"
contabase_dir="$CM_PATH/data/contabase"

## Display prepared contaminants from the contabase
printf "<contabase>\n"
for category_id in $(list_categories "$contabase")
do
    printf "    <category>\n"
    printf "        <id>%s</id>\n" "$category_id"
    default=$(getXpath "//category[id='$category_id']/default/text()" \
        "$contabase")
    printf "        <default>%s</default>\n" "$default"
    for uniprot_id in $(\
        list_contaminants_in_category "$category_id" "$contabase")
    do
        if [ -d "$contabase_dir/$uniprot_id" ]
        then
            printf "        <contaminant>\n"
            printf "            <uniprot_id>%s</uniprot_id>\n" "$uniprot_id"
            short_name="$(getXpath \
                "//contaminant[uniprot_id='$uniprot_id']/short_name/text()" \
                "$contabase")"
            printf "            <short_name>%s</short_name>\n" "$short_name"
            long_name="$(getXpath \
                "//contaminant[uniprot_id='$uniprot_id']/long_name/text()" \
                "$contabase")"
            printf "            <long_name>%s</long_name>\n" "$long_name"
            organism="$(getXpath \
                "//contaminant[uniprot_id='$uniprot_id']/organism/text()" \
                "$contabase")"
            printf "            <organism>%s</organism>\n" "$organism"
            exact="$(getXpath \
                "//contaminant[uniprot_id='$uniprot_id']/exact/text()" \
                "$contabase")"
            printf "            <exact_model>%s</exact_model>\n" "$exact"

            # Add ref and sugg
            for pubmed_id in $(getXpath \
                "//contaminant[uniprot_id='$uniprot_id']//pubmed_id/text()" \
                "$contabase")
            do
                printf "            <reference>\n"
                printf "                <pubmed_id>%s</pubmed_id>\n" \
                    "$pubmed_id"
                printf "            </reference>\n"
            done
            for sugg_name in $(getXpath \
                "//contaminant[uniprot_id='$uniprot_id']/suggestion/name/text()" \
                "$contabase")
            do
                printf "            <suggestion>\n"
                printf "                <name>%s</name>\n" "$sugg_name"
                printf "            </suggestion>\n"
            done
            extractPacks "$contabase_dir/$uniprot_id/models/model_prep.xml" \
                | sed 's/^/            /'
        fi
    done
done
printf "</contabase>\n"
