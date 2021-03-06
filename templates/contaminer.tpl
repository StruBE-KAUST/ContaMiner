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

## Main script to control ContaMiner
## $1 : command to run
## $2... : Parameters for the command

CM_PATH=
export CM_PATH

# Change to POSIX mode
{
    # shellcheck source=../scripts/posix_mode.sh
    . "$CM_PATH/scripts/posix_mode.sh"
} || {
    printf "Directory seems to be corrupted. Please check.\n"
    exit 1
}

case $1 in
    init)
        sh "$CM_PATH/scripts/initialize.sh"
        ;;
    update)
        sh "$CM_PATH/scripts/update.sh"
        ;;
    status)
        sh "$CM_PATH/scripts/status.sh"
        ;;
    display)
        sh "$CM_PATH/scripts/display.sh"
        ;;
    solve)
        if [ $# -ge 3 ]
        then
            sh "$CM_PATH/scripts/solve.sh" "$2" "$3"
        else
            sh "$CM_PATH/scripts/solve.sh" "$2"
        fi
        ;;
    job_status)
        sh "$CM_PATH/scripts/job_status.sh" "$2"
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
        printf "  init - prepare the models for the first time"
        printf "  status - show if the ContaBase is ready\n"
        printf "  display - display the ContaBase in XML format\n"
        printf "  update - prepare the models after a MoRDa update\n"
        printf "  solve - detect a contaminant\n"
        printf "  job_status - gives the status of a job\n"
        printf "\n"
        printf "See the README.md file for more information about the "
        printf "available commands.\n"
        printf "GitHub repository is available here:\n"
        printf "https://github.com/StruBE-KAUST/ContaMiner\n"
        printf "\t\tThis tool does not have a Partial Platypus Power.\n"
        ;;
esac
