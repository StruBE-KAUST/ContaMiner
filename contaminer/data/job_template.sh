#!/bin/sh

cd /home/ahungler/KAUST/ContaMiner
source venv/bin/activate
source /home/ahungler/ccp4/ccp4-7.1/bin/ccp4.setup-sh
seq 1 %NB_PROCS% | xargs -n 1 -P 12 -I {} contaminer %COMMAND% {}
