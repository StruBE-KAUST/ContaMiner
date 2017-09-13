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

## Provide functions to list the parameters for each task for one job

# Create a custom model directory for a custom contaminant
# $1: filepath of the custom PDB file
# $2: Parent directory where to create the model folder
# Print created directory name on stdout
create_model_dir () {
    # Check number of arguments
    if [ $# -lt 2 ]
    then
        printf "Wrong number of arguments\n" >&2
        return 1
    fi

    # Create folder
    model_dir="$2/c_$(basename "$1" | cut --delimiter="." -f1)"
    {
        mkdir "$model_dir"
    } || {
        printf "%s: Model directory cannot be created. " "$model_dir" >&2
        printf "Skipping...\n" >&2
        return 1
    }
    {
        cp "$1" "$model_dir/custom.pdb"
    } || {
        printf "Cannot copy file: %s. " "$1" >&2
        printf "Skipping...\n" >&2
        rm -r "$model_dir"
        return 1
    }
    cp "$CM_PATH/templates/model_prep.xml" "$model_dir"
    printf "%s" "$(basename "$model_dir")"
    return 0
}

# Clean a list of contaminants
# $1: list of contaminants, comma separated
# $2: directory where the jobs will be executed
# Print same list of contaminants on stdout, without the non-testable ones
# Create custom models if needed
clean_contaminants () {
    # Check number of arguments
    if [ $# -lt 2 ]
    then
        printf "Wrong number of arguments\n" >&2
        return 1
    fi

    # Loop on contaminants. Check if CB is ready, or create custom dir.
    contaminant_ids=$( \
    printf "%s\n" "$1" | tr "," "\n" \
        | while IFS= read -r contaminant
    do
        case $contaminant in
            /*|./*|../*)
                # Custom contaminant
                if contaminant_id="$(create_model_dir "$contaminant" "$2")"
                then
                    printf "%s," "$contaminant_id"
                fi
                ;;
            *)
                # ContaBase contaminant
                if [ -d "$CM_PATH/data/contabase/$contaminant" ]
                then
                    printf "%s," "$contaminant"
                else
                    printf "Contaminant not in ContaBase: %s\n" "$contaminant" >&2
                fi
                ;;
        esac
    done
                   )
    if [ -z "$contaminant_ids" ]
    then
        printf "No contaminant in the list. Nothing will be tested.\n" >&2
    else
        printf "%s" "${contaminant_ids%?}"
    fi
}

# List all parameters, seprated by a comma (CSV style)
# $1: contaminants list, comma separated. Custom contaminants must start with c_
# $2: space groups, comma separated. Can be in space or slug formatting.
# Print list of parameters and scores on stdout, one per line, comma separated
# Format is:
# contaminant_id,pack_number,space_group,score
# env: CM_PATH
list_parameters_scores () {
   # Load XML tools
    xml_tools="$CM_PATH/scripts/xmltools.sh"
    # shellcheck source=xmltools.sh
   . "$xml_tools"
    
    # Check number of arguments
    if [ $# -lt 2 ]
    then
        printf "Wrong number of arguments\n" >&2
        return 1
    fi

    # Rename vars
    contaminants_list="$1"
    space_groups="$2"

    # Loop on contaminants
    printf "%s\n" "$contaminants_list" | tr "," "\n" \
    | while IFS= read -r contaminant_id
    do
        # Custom contaminants should start with c_
        case $contaminant_id in
            c_*)
                # Custom contaminant
                contaminant_score=1
                pack=1
                pack_score=1
                printf "%s\n" "$space_groups" | tr "," "\n" \
                    | while IFS= read -r alt_sg
                do
                    print_parameters_scores \
                        "$contaminant_id" "$pack" "$alt_sg" \
                        "$(( contaminant_score * pack_score ))"
                done
            ;;
            *)
                # ContaBase contaminant
                ml_scores_file="$CM_PATH/data/ml_scores.xml"
                contaminant_score=$( getXpath \
                    "//contaminant[uniprot_id=$contaminant_id]/score/text()" \
                    "$ml_scores_file" \
                                 )
                pack_file="$CM_PATH/data/contabase/$contaminant_id/packs"
                
                # Remove comments and empty lines, then loop on packs
                grep -v '^ *#' < "$pack_file" \
                    | grep -v '^$' \
                    | while IFS= read -r pack_line
                do
                    pack=$(printf "%s" "$pack_line" \
                        | cut --delimiter=':' -f1)
                    pack_score=$(printf "%s" "$pack_line" \
                                     | cut --delimiter=':' -f2)
                    printf "%s\n" "$space_groups" | tr "," "\n" \
                        | while IFS= read -r alt_sg
                    do
                        print_parameters_scores \
                            "$contaminant_id" "$pack" "$alt_sg" \
                            "$(( contaminant_score * pack_score ))"
                    done
                done
                ;;
        esac
    done
}

# Print the descripting line for the task with given parameters
# $1: contaminant_id
# $2: pack number
# $3: space group (spaced or slugged)
# $4: contaminant_pack_score (contaminant_score * pack_score)
# print on stdout: $1,$2,slugged($3),score(task)
# env: CM_PATH
print_parameters_scores () {
    # Load XML tools
    xml_tools="$CM_PATH/scripts/xmltools.sh"
    # shellcheck source=xmltools.sh
   . "$xml_tools"
    
    # Check number of arguments
    if [ $# -lt 4 ]
    then
        printf "Wrong number of arguments\n" >&2
        return 1
    fi
    
    alt_sg_slug=$(printf "%s" "$3" | sed "s/ /-/g")
    alt_sg_space=$(printf "%s" "$3" | sed "s/-/ /g")

    ml_scores_file="$CM_PATH/data/ml_scores.xml"
    sg_score=$( \
                getXpath "//space_group[name='$alt_sg_space']/score/text()" \
                         "$ml_scores_file" \
            )
    task_score=$(( $4 * sg_score ))
    printf "%s,%s,%s,%s\n" \
           "$1" "$2" "$alt_sg_slug" "$task_score"
}

# Write the content of the results file
# 
# $1: contaminants list, comma separated. Custom contaminants must start with c_
# $2: space groups, comma separated. Can be in space or slug formatting.
# Print list of parameters on stdout, one per line, comma separated
# Format is:
# contaminant_id,pack_number,space_group,new,0,0,0h 00m 00s
# env: CM_PATH
results_content () {
    # Check number of arguments
    if [ $# -lt 2 ]
    then
        printf "Wrong number of arguments\n" >&2
        return 1
    fi

    # List then sort, then cut the score
    list_parameters_scores "$1" "$2" | sort -rk 4 -t ',' -g \
        | while IFS= read -r line
        do
            taskid=$(printf "%s" "$line" | cut --delimiter=',' -f1-3)
            printf "%s,new,0,0,0h 00m 00s\n" "$taskid"
        done
}
