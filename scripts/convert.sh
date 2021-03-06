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

## Provide functions to convert cif file to mtz, and check integrity

# Convert file CIF file $1 to MTZ file $2
toMtz () {
    printf "END" | cif2mtz HKLIN "$1" HKLOUT "$2" > /dev/null
}

# Check if $1 is a valid MTZ file
checkMtz () {
    return_code=0
    if mtzdmp "$1" 2>/dev/null | grep -q "Error"
    then
        return_code=1
    fi
    return $return_code
}

# Check if $1 is a CIF file, convert it to a MTZ file named as $1 with the
# extension .mtz, then check if the new created file is valid
safeToMtz () {
	if [ $# -ne 1 ] || printf "%s" "$1" | grep -vq ".*\.\(mtz\|cif\)"
	then
		printf "Wrong number of arguments or wrong file type.\n"
		return 1
	fi
	if [ ! -f "$1" ]
	then
		printf "File %s does not exist.\n" "$1"
		return 1
	fi

    mtz_file_name=$(printf "%s" "$1" | sed 's/\.cif/\.mtz/')

    if printf "%s" "$1" | grep -q ".*\.cif"
    then
        toMtz "$1" "$mtz_file_name" 2> /dev/null
    fi

    if ! checkMtz "$mtz_file_name"
    then
        return 1
    fi
}

## Convert MTZ file to 2 MAP files (1 elec. dens. map and 1 diff)
## $1 : path to MTZ file to convert
## $2 : path to elec. dens. map output file
## $3 : path to diff map output file
named_mtz2map () {
    commands="read $1
fft col FWT PHWT
mapout $2
delete map
fft col DELFWT PHDELWT
mapout $3"
    printf "%s" "$commands" | sftools >/dev/null
}

## Convert MTZ file to 2 MAP files
## $1 : path to MTZ file to convert
## Write $1{.mtz -> .map} (full elec. dens. map)
## Write $1{.mtz -> .diff.map} (diff elec. dens. map)
mtz2map () {
    map_file=$(echo "$1" | sed 's/.mtz$/.map/')
    map_diff_file=$(echo "$1" | sed 's/.mtz$/.diff.map/')
    named_mtz2map "$1" "$map_file" "$map_diff_file"
}
