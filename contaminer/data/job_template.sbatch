#!/bin/sh

#SBATCH --ntasks=1
#SBATCH --mem=8G
#SBATCH --time=1-0:00:00
#SBATCH --array=%MIN_ARRAY%-%MAX_ARRAY%
#SBATCH --requeue
#SBATCH --account=cbrc-strube
#SBATCH -J CM_%PREP_NAME%

set -e

# Let enough time to automount to mount my directory
ls /ibex/scratch/cbrc-strube > /dev/null 2>&1 || sleep 5
ls /ibex/scratch/cbrc-strube > /dev/null # Fail here if directory is not available.

# Load environment
# No need, as the job is submitted from an environment which already sources all of that.
# module load anaconda3
# source activate /ibex/scratch/cbrc-strube/conda-env
source /ibex/scratch/cbrc-strube/ccp4-7.0/bin/ccp4.setup-sh
source /ibex/scratch/cbrc-strube/MoRDa_DB/morda_env_sh

# Heavy lifting
printf "Starting ContaMiner...\n"
contaminer %COMMAND% %PREP_DIR% $SLURM_ARRAY_TASK_ID
printf "ContaMiner ended.\n"
