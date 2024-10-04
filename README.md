# What is this?

This repository contains the source code of ContaMiner. You can find a quick
description of ContaMiner on the [StruBE
website](https://strube.cbrc.kaust.edu.sa/contaminer).

Because you are special (indeed, not many people will read this README), I
added a little description for you. OK, you can read the same on the [StruBE
website](https://strube.cbrc.kaust.edu.sa/contaminer).

# What is ContaMiner?
ContaMiner is a rapid large-scale detection of contaminant crystals.

Protein contaminants from the expression host, purification buffers or from
affinity tags, may crystallize instead of the protein of interest.
Unfortunately, this only becomes clear once the crystal structure has been
determined...

ContaMiner allows rapid screening of X-ray diffraction data against the most
likely protein contaminants.

## How does it work?
Given an mtz or cif data file, ContaMiner uses an optimized molecular
replacement procedure, based on MoRDa automatic molecular replacement pipeline.

# How to use it?
If you are reading this file, I guess you want to use ContaMiner on your own
cluster / supercomputer / whatever with many CPUs. These instructions are for
you. If you did not understand what I just said, use the [online
webservice](https://strube.cbrc.kaust.edu.sa/contaminer). It is much easier,
trust me!

## What specifications do I need?
While ContaMiner can technically run on a Pentium III @600MHz with 256MB RAM,
the mean case will take 6.8 years of intensive computation.
We recommand using as many cores as possible with a maximum of 2512. More cores
are useful only if you want to run parallel sessions of ContaMiner.
The basic configuration is done to use 1 core per task. If you have any
technical reason to change this setting (different number of FPUs than cores),
use a custom job template. For example:
`#SBATCH --nstasks 2`
As molecular replacement is essentially computation of Fourier transform, the
I/O is usually not a limiting resource.

## What dependancies do I need?
ContaMiner is based on MoRDa. MoRDa is based on CCP4 tools. Therefore, you need
CCP4 and MoRDa installed on your cluster / supercomputer / whatever with many
CPUs. ContaMiner is designed to work on a cluster or a supercomputer. Job
templates for xargs and SLURM come with ContaMiner, but you can easily adapt it
to use any other scheduler.

ContaMiner is written in Python. Python3 is therefore another dependancy, as
well as the packages listed in the file requirements.txt. Conda or virtualenv
can be useful to install the dependancies.

## How to install it?
ContaMiner needs CCP4 and MoRDa. You can find them here :
[CCP4: Software for Macromolecular Crystallography](http://www.ccp4.ac.uk)
[Morda - Biomex Solutions](http://www.biomexsolutions.co.uk/morda/)

Download and install them by following the given instructions on the two
websites. It can take some time.
Warning! ContaMiner does not support MoRDa installed with the CCP4 setup tool.
MoRDa must be installed as a standalone software as described in the link
above.

Next, you need to install ContaMiner, possibly in a virtualenv or conda env.
I let you create the environment as you wish. Make sure to use a Python3.

Then install ContaMiner itself. With pip, you can run:
> pip install git+https://github.com/StruBE-KAUST/ContaMiner.git

To generate a default configuration file, run any ContaMiner command. For
example:
>  contaminer --help
This command should describe how to run ContaMiner. It has also written a
default (and likely incomplete) configuration file in
`~/.contaminer/config.ini`. Open this file and edit the missing variables.

Also make sure to use an adequate job_template. The default value uses xargs
and 12 cores, but it is very likely not what you want to do. The easiest way
if to copy the file used by default somewhere else, edit it to match your
requirements (keep the %% tags in place), and indicate the new template path
in the config file.

ContaMiner needs to run preparation steps before being taking your diffraction
data. To "initialize the ContaBase" (meaning, to run morda_prep for each
possible contaminant), simply run:
> contaminer init

The command can take a long time to return, depending on your job template and
the computation resources you have. If you encounter an error at this stage,
something must be missing from the installation. The error message should help
you solve the issue. Possible things to check are:

- make sure ccp4 and MoRDa are properly installed
- check the validity of the configuration file
- make sure the configured job_template matches your infrastructure (you
do not want to use xargs on a cluster, and do not want to use sbatch on a
personal laptop).

## How do I use ContaMiner?
When the initialization is complete (`contaminer init-status` returns "Ready")
run a task with:
> contaminer solve my-diffraction-file.mtz

This command will create a directory in your current directory, with the same
name as your MTZ or CIF file. It will also run the necessary steps to check your
diffraction file against the most common contaminants.
You can specify which contaminants you want to check by adding other arguments:
> contaminer solve my-diffraction-file.mtz P0A9K9 P0ACJ8

Any additional argument is a UniprotID of contaminants to check. Only
contaminants present in the ContaBase (available with
`contaminer show contabase`) are accepted.

Check the progress of the job with:
> contaminer solve-status

To get the
This command returns a large output in JSON format.



Each line of `results.txt` follows this pattern :
> Contaminant,Pack number,Space group,Percent,Q factor,Status,Time

where :
- `Contaminant` is the uniprot ID of the tested contaminant or c\_ followed
  by the file name in the case of a user provided model.
- `Pack number` is the number of the pack (according to the directory created by
  morda\_prep)
- `Space group` is the tested space group
- `Percent` is the probability this molecular replacement is a solution (the
  user should consider the result as positive if B>90%, otherwise negative)
- `Q factor` is the Q factor given by morda\_solve
- `Status` is the status of the process. It can be :
  - New: if the process did not run at all
  - Running: if the process is currently running
  - Complete: if the process reached the final stage
  - Aborted: if the process has been killed before the end by a tiem limit
  - Error : if morda\_solve encountered an error
- Time can be '0h 0m 0s' if the job did not run at all or is running, or a
  non-zero value displaying how long the process was running before completion
  or cancellation.

The best way to check if a positive result was found is to scan the results.txt
file with grep.
> grep -E -- "-9[0-9]-" results.txt

gives you the lines with a probability higher or equal to 90%.

### Edit job_template.sh
