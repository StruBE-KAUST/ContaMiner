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

## Provide functions to convert cif file to mtz, and check integrity

convert2mtz () {
    filename=$1
    if printf "$1" | grep -q ".*\.cif"
    then
        filename=$(printf "$1" | sed 's/\.cif/\.mtz/')
        printf "END" | cif2mtz HKLIN "$1" HKLOUT "$filename" > /dev/null
    fi
    printf "$filename"
}

check () {
    if [ -n "$(mtzdmp "$1" | grep "Error")" ]
    then
        exit 1
    fi
}

safe_convert () {
	if [ $# -ne 1 ] || printf "$1" | grep -vq ".*\.\(mtz\|cif\)"
	then
		printf "Wrong number of arguments or wrong file type.\n"
		exit 1
	fi
	if [ ! -f $1 ]
	then
		printf "File $1 does not exist.\n"
		exit 1
	fi
    mtz_file_name=$(convert2mtz $1)
    check "$mtz_file_name"
    if [ $? -ne 0 ]
    then
        printf "The conversion of $1 is not possible.\n"
        exit $?
    fi
}
