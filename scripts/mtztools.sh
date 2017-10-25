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

## Provide functions to deal with MTZ files

# Extract space_group from an MTZ file
# $1: MTZ filename
# Print spaced space group on stdout
# env: CCP4
get_space_group () {
    # Check input
    if [ $# -lt 1 ] || printf "%s" "$1" | grep -vq ".*\.\(mtz\|cif\)"
    then
        printf "Missing argument\n" >&2
        return 1
    fi
    if [ ! -f "$1" ]
    then
        printf "File %s does not exist.\n" "$1" >&2
        return 1
    fi

    {
        space_group=$(mtzdmp "$1" | grep "Space group" \
            | sed "s/.*'\(.*\)'.*/\1/")
    } || {
        return 1
    }
    printf "%s\n" "$space_group"
}

# Get alternate space groups from an MTZ file
# $1: MTZ filename
# Print alternate spaced space groups on stdout, comma separated
# env: CCP4
get_alternate_space_groups () {
    # Check input
    if [ $# -lt 1 ] || printf "%s" "$1" | grep -vq ".*\.\(mtz\|cif\)"
    then
        printf "Missing argument\n" >&2
        return 1
    fi
    if [ ! -f "$1" ]
    then
        printf "File %s does not exist.\n" "$1" >&2
        return 1
    fi

    space_group=$(get_space_group "$1")

    commands="N\nSG $space_group\n\n"
    # In order :
    # Put everything on same line
    # Remove everything before result
    # Change middle numbers + quotes to comma
    # Remove last quote
    # Remove 1 + quote at the beginning
    alt_space_groups=$(printf "%b" "$commands" | alt_sg_list \
        | tr -d '\n' \
        | sed 's/.*-->\ *\(1.*\)/\1/' \
        | sed 's/"\ *[0-9]\ *"/,/g' \
        | sed 's/"$//' \
        | sed 's/1\ *"//' \
        )
    printf "%s" "$alt_space_groups"
}
