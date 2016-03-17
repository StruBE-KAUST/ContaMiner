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
##
## define_dir.sh version 1.0.0
## Define the different directories for the project.

# POSIX mode
if [ -n "$BASH_VERSION" -o -n "$KSH_VERSION" ]
then
    set -o posix
fi
if [ -n "$ZSH_VERSION" ]
then
    emulate sh
    NULLCMD=:
fi

# ContaMiner paths
define_paths=""
scripts_path=$(dirname $define_paths)
cm_path=$(dirname $scripts_path)
cm_script="$cm_path/contaminer"
data_path="$cm_path/data"
contam_path="$data_path/contaminants"
init_path="$data_path/init"
contam_init_file="$init_path/contaminants.txt"
big_struct_cif="$contam_path/big_struct.cif"
sg_scores_file="$data_path/sg_scores.txt"

# CCP4 and MoRDa paths
source1=""
source2=""
source3=""

if [ -n "$source1" ]
then
    . $source1
    . $source2
    . $source3
fi
