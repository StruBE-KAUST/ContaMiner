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

## Return 0 if all the contaminants are ready
## Return 1 if at least one contaminant preparation is not complete
## $1 : contabase directory
is_prepared () {
    if [ -z "$(\
        find "$1" -maxdepth 1 -mindepth 1 -type d \
        -exec sh -c \
        'if [ ! -f "$1/packs" ] || [ -d "$1/scr_prep" ] || [ ! -d "$1/models" ]
            then
                printf "1"
            fi' _ {} \;)" ]
    then
        return 0
    else
        return 1
    fi
}

## Return true if all the preparations are started
## Return false if at least one contaminant preparation is not started
## $1 : contabase directory
is_started () {
    if [ -z "$(\
        find "$1" -maxdepth 1 -mindepth 1 -type d \
        -exec sh -c \
            'if [ ! -f "$1/packs" ]
            then
                printf "1"
            fi' _ {} \;)" ]
    then
        return 0
    else
        return 1
    fi
}

cm_path="$(dirname "$(dirname "$(readlink -f "$0")")")"
contabase_dir="$cm_path/data/contabase"

if [ -d "$contabase_dir" ]
then
    if is_prepared "$contabase_dir"
    then
        printf "ContaBase is ready.\n"
    elif is_started "$contabase_dir"
    then
        printf "ContaBase is being initialized.\n"
    else
        printf "ContaBase is not ready. You should start the initialization.\n"
    fi
else
    printf "ContaBase is not ready. You should start the initialization.\n"
fi
