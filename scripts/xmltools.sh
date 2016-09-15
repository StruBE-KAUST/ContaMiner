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

## Provide a function to get elements from an XML file, based on a XPath

## $1 : XPath
## $2 : XML file
getXpath () {
    if [ $# -ne 2 ]
    then
        printf "Wrong number of arguments.\n"
        return 1
    fi
    if [ ! -f "$2" ]
    then
        printf "%s does not exist.\n" "$2"
        return 1
    fi
    printf "cat %s\n" "$1" | xmllint --shell "$2" \
        | grep -v "/ >" \
        | grep -v -- "-------" \
        | grep -v "$^" \
        | awk '{$1=$1};1'
}
