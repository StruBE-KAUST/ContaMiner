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

## Provide a function to get elements from an XML file, based on a XPath

## $1 : command
## $2 : XML file
XMLshell () {
    if [ $# -ne 2 ]
    then
        printf "Wrong number of arguments.\n" >&2
        return 1
    fi
    if [ ! -f "$2" ]
    then
        printf "%s does not exist.\n" "$2" >&2
        return 1
    fi
    printf "%b\n" "$1" | xmllint --shell "$2"
}

## $1 : XPath
## $2 : XML file
getXpath () {
    XMLshell "cat $1" "$2" \
        | grep -v "/ >" \
        | grep -v -- "-------" \
        | grep -v "$^" \
        | awk '{$1=$1};1'
}

## $1 : XPath
## $2 : Value to set
## $3 : XML file
setXpath (){
    XMLshell "cd $1\nset $2\nsave" "$3" >/dev/null
}

## Print the number of nodes for an XPath.
## $1 : Xpath
## $2 : XML file
## Given number is >= 0
countXpath () {
    # Args check is made by XMLshell
    if [ -z "$1" ]
    then
        printf "Wrong number of arguments.\n" >&2
        return 1
    fi
    XMLshell "xpath count($1)" "$2" \
        | grep "Object is a number" \
        | sed -e 's/\/ > Object is a number : \([:digit:]*\)/\1/'
}

## $1 : structure position (int)
## $2 : model position (int)
## $2 : XML file
extractModel () {
    pdb_code_chain=$(getXpath "//structure[$1]/PDB_code/text()" "$3")
    domain=""
    if [ "$pdb_code_chain" = "MDOM" ]
    then
        pdb_code_chain=$( \
            getXpath "//structure[$1]/model[$2]/domain_code/text()" "$3")
        domain=$(printf "%s" "$pdb_code_chain" | cut -c 7-)
    else
        domain=$(getXpath "//structure[$1]/model[$2]/domain/text()" "$3")
    fi
    pdb_code=$(printf "%s" "$pdb_code_chain" | cut -c -4)

# Does not work for multimers
#    chain_code=$(printf "%s" "$pdb_code_chain" | cut -c 5)

    chain_code=$(getXpath \
        "//structure[$1]/model[$2]/chain/text()" "$3")
    n_res=$(getXpath "//structure[$1]/model[$2]/nres/text()" "$3")
    identity=$(getXpath "//structure[$1]/model[$2]/similarity/text()" "$3")

    printf "\
<model>\n\
    <template>%s</template>\n\
    <chain>%s</chain>\n\
    <domain>%s</domain>\n\
    <n_res>%s</n_res>\n\
    <identity>%s</identity>\n\
</model>\n" \
        "$pdb_code" \
        "$chain_code" \
        "$domain" \
        "$n_res" \
        "$identity"
}

## $1 : structure position
## $2 : position of the pack's first model
## $3 : XML file
extractPack () {
    quat_structure=""
    cursor="$2"
    end=false

    printf "<pack>\n"

    # Determine quat structure
    pdb_code=$(getXpath \
        "//structure[$1]/PDB_code/text()" \
        "$3")
    if [ "$pdb_code" = "MDOM" ]
    then
        quat_structure="domains"
    else
        chain=$(getXpath \
            "//structure[$1]/model[$2]/chain/text()" \
            "$3")
        chain_length=${#chain}
        if [ "$chain_length" -gt 1 ]
        then
            complex=$(getXpath \
                "//structure[$1]/model[$2]/complex/text()" \
                "$3")
            if [ "$complex" -eq 222 ]
            then
                quat_structure="4-mer"
            else
                quat_structure="$(( complex / 100 ))-mer"
            fi
        else
            domain=$(getXpath \
                "//structure[$1]/model[$2]/domain/text()" \
                "$3")
            if [ "$domain" -eq 1 ]
            then
                quat_structure="domains"
            else
                quat_structure="1-mer"
            fi
        fi
    fi 
    printf "\
    <quat_structure>%s</quat_structure>\n" \
        "$quat_structure"

    # Loop on models
    while [ "$end" = "false" ]
    do
        next_domain=$( \
            getXpath \
                "//structure[$1]/model[$((cursor +1))]/domain/text()" \
                "$3")
        if [ -z "$next_domain" ] \
            || [ "$next_domain" -eq 0 ] \
            || [ "$next_domain" -eq 1 ]
        then
            end=true
        fi

        model=$(extractModel "$1" "$cursor" "$3" | sed 's/^/    /')
        printf "%s\n" "$model"
        cursor=$(( cursor +1 ))
    done

    printf "</pack>\n"
}

## $1 : XML file
## env must contain MODEL_CURSOR and STRUCTURE_CURSOR
## (No need to initialise them)
extractNextPack () {
    if [ -z "$MODEL_CURSOR" ] || [ -z "$STRUCTURE_CURSOR" ]
    then
        MODEL_CURSOR=1
        STRUCTURE_CURSOR=1
    fi
    test_pack=$( \
        getXpath \
        "//structure[$STRUCTURE_CURSOR]/model[$MODEL_CURSOR]" \
        "$1" )
    if [ -z "$test_pack" ]
    then
        STRUCTURE_CURSOR=$(( STRUCTURE_CURSOR +1 ))
        MODEL_CURSOR=1

        test_pack=$( \
            getXpath \
            "//structure[$STRUCTURE_CURSOR]/model[$MODEL_CURSOR]" \
            "$1" )

        if [ -z "$test_pack" ]
        then
            unset STRUCTURE_CURSOR
            unset MODEL_CURSOR
            return 1
        fi
    fi
    pack=$(extractPack "$STRUCTURE_CURSOR" "$MODEL_CURSOR" "$1")
    nb_models=$(printf "%s" "$pack" | grep -c "<model>")
    MODEL_CURSOR=$(( MODEL_CURSOR +nb_models ))

    printf "%s\n" "$pack"
}

## $1 : XML file
extractPacks () {
    unset MODEL_CURSOR
    unset STRUCTURE_CURSOR
    export MODEL_CURSOR
    export STRUCTURE_CURSOR
    while extractNextPack "$1"
    do
        :
    done
}

## $1 : XML file (ContaBase)
list_categories () {
    getXpath "//category/id/text()" "$1"
}

## $1 : category id
## $2 : XML file
list_contaminants_in_category () {
    getXpath "//category[id='$1']/contaminant/uniprot_id/text()" "$2"
}
