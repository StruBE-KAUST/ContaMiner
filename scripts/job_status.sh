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

## Return 0 if the job has been submitted
## Return 1 otherwise
## $1 : path to the expected job directory
## Test if the directory is created
is_submitted () {
    if [ -d "$1" ]
    then
        return 0
    else
        return 1
    fi
}

## Return 0 if the job is running
## Return 1 otherwise
## $1 : path to the expected job directory
## Test if a corresponding line exists in squeue
is_running () {
    matching_tasks=$( \
        squeue -u "$(whoami)" i-o %o \
        | grep "$(basename "$1")" \
        | grep "R" \
        )
    if [ -n "$matching_tasks" ]
    then
        return 0
    else
        return 1
    fi
}

## Return 0 if the job is complete
## Return 1 otherwise
## $1 : path to the expected job directory
## Test if a corresponding line exists in squeue
is_complete () {
    matching_tasks=$( \
        squeue -u "$(whoami)" i-o %o \
        | grep "$(basename "$1")" \
        )
    if [ -z "$matching_tasks" ]
    then
        return 0
    else
        return 1
    fi
}

## Return 0 if the job encountered errors for all the tasks
## Return 1 otherwise
## $1 : path to the expected job directory
## Test if at least one line in results.txt is not error
is_error () {
    if is_running "$1"
    then
        return 1
    elif [ ! -f "$1/results.txt" ]
    then
        return 0
    elif ! grep -vq "error" "$1/results.txt"
    then
        return 0
    else
        return 1
    fi
}

if [ $# -lt 1 ]
then
    printf "Missing argument\n" >&2
    printf "Usage: contaminer job_status JOB_DIRECTORY\n" "$0" >&2
    printf "\n" >&2
    printf "where JOB_DIRECTORY is the directory created by " >&2
    printf "contaminer when submitting a solve job.\n" >&2
    exit 1
fi

if is_error "$1"
then
    printf "Job encountered an error\n"
elif is_complete "$1"
then
    printf "Job is complete\n"
elif is_running "$1"
then
    printf "Job is running\n"
elif is_submitted "$1"
then
    printf "Job is submitted\n"
else
    printf "Job does not exist\n"
fi
