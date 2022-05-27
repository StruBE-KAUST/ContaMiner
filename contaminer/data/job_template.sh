#!/bin/sh

cd /home/ahungler/KAUST/ContaMiner
. venv/bin/activate
. /home/ahungler/KAUST/ccp4-7.1/bin/ccp4.setup-sh
. /home/ahungler/KAUST/MoRDa_DB/morda_env_sh
seq %MIN_ARRAY% %MAX_ARRAY% | xargs -n 1 -P 12 -I {} contaminer %COMMAND% {}
