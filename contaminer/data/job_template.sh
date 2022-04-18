#!/bin/sh

cd /home/ahungler/KAUST/ContaMiner
source venv/bin/activate
source /home/ahungler/ccp4/ccp4-7.1/bin/ccp4.setup-sh
#echo "NB_PROCS: %NB_PROCS%"
#echo "MIN_ARRAY: %MIN_ARRAY%"
#echo "MAX_ARRAY: %MAX_ARRAY%"
#echo "COMMAND: %COMMAND%"
seq %MIN_ARRAY% %MAX_ARRAY% | xargs -n 1 -P 12 -I {} contaminer %COMMAND% {}
#nohup contaminer %COMMAND% 0 > ~/init.log 2>&1
