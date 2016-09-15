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

## Define the different directories for the project.

# ContaMiner paths
define_paths=""
scripts_path=$(dirname "$define_paths")
cm_path=$(dirname "$scripts_path")
cm_script="$cm_path/contaminer"
data_path="$cm_path/data"
contaminants_dir="$data_path/contaminants"
init_path="$data_path/init"
contaminants_list="$init_path/contaminants.txt"
sg_scores="$data_path/sg_scores.txt"

# CCP4 and MoRDa paths
SOURCE1=""
SOURCE2=""
SOURCE3=""

export contaminants_dir
export sg_scores
export contaminants_list
export SOURCE1
export SOURCE2
export SOURCE3
