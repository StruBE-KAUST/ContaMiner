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

## Main script to control ContaMiner
## $1 : command to run
## $2... : Parameters for the command

CM_PATH=
export CM_PATH

define_paths="$CM_PATH/scripts/define_paths.sh"
if [ ! -f "$define_paths" ]
then
    printf "Installation seems corrupted. " >&2
    printf "Please re-install ContaMiner.\n" >&2
    exit 1
fi

case $1 in
    initialize)
        sh "$CM_PATH/scripts/initialize.sh"
        ;;
    update)
        sh "$CM_PATH/scripts/update.sh"
        ;;
    solve)
        sh "$CM_PATH/scripts/solve.sh"
        ;;
    *)
        printf "ContaMiner v2.0.0\n"
        printf "Usage: %s COMMAND [PARAMETERS]\n" "$0"
        printf "\n"
        printf "ContaMiner is a rapid automated large-scale detector of "
        printf "contaminants crystals. If this tool was usefull, please "
        printf "cite:\n"
        printf "Hungler A, Momin A, Diederichs K and Arold ST\n"
        printf "ContaMiner and ContaBase: a web server and database for early "
        printf "identification of unwantedly crystallized protein "
        printf "contaminants\n"
        printf "J. Appl. Cryst., 49:2252-2258\n"
        printf "\n"
        printf "Available commands:\n"
        printf "  initialize - prepare the models for the first time"
        printf "contaminant\n"
        printf "  update - prepare the models after a MoRDa update\n"
        printf "  solve - detect a contaminant\n"
        printf "\n"
        printf "See the README.md file for more information about the "
        printf "available commands.\n"
        printf "GitHub repository is available here:\n"
        printf "https://github.com/StruBE-KAUST/ContaMiner\n"
        printf "\t\tThis tool does not have a Partial Platypus Power.\n"
        ;;
esac
