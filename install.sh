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
## install.sh version 1.0.0
## Install ContaMiner and create the database

set -e

# Change own_path var to define_paths in define_paths.sh
define_paths=$(dirname $(readlink -f $0))"/scripts/define_paths.sh"
sed -i "s,define_paths=.*,define_paths=\"$define_paths\"," $define_paths

. $define_paths

PATH="$scripts_path:$PATH"
export PATH
export define_paths

configure.sh

# Add the $define_path indication to contaminer main script
sed -i "s,define_paths=.*,define_paths=\"$define_paths\"," "$cm_script"

initialise.sh

printf "When the jobs are completed, the initilisation is finished. Then you \
can use ContaMiner. To check the jobs running for your user, you can use :\n\
squeue -u $(whoami)\n"

printf "You can now move the contaminer script wherever you want on your \
operating system. You can, for example, move it in your a directory listed \
in your PATH.\n"
