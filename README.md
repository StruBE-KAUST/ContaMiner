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
We recommand using as many CPUs as possible with a maximum of 2512. More CPUs
are useful only if you want to run parallel sessions of ContaMiner.
Number of cores does not matter, as ContaMiner tries to use one FPU per task. 
The basic configuration is done to use 1 CPU per task. If you have less than 1 
FPU per CPU, increase this option. For example, if you have one FPU per 2 CPUs, 
you should set this option :
`#SBATCH --nstasks 2`
As molecular replacement is essentially computation of Fourier transform, the
I/O is not a limiting resource.

## What dependancies do I need?
ContaMiner is based on MoRDa. MoRDa is based on CCP4 tools. Therefore, you need
CCP4 and MoRDa installed on your cluster / supercomputer / whatever with many
CPUs. ContaMiner is designed to work on a cluster or a supercomputer. Currently,
the only supported workload manager is SLURM. LSF and SGE could be supported
later.

The set of scripts is written to be POSIX compliant. While many shells are
not totally POSIX-compliant, the scripts are working, at least, with
-   Ash
-   Bash
-   Ksh
-   Pdksh
-   Zsh

One last dependancy is lockfile. For most of the operating systems, this command
is part of the procmail package. We need lockfile instead of flock, lockf, fcntl
or any POSIX solution, because the file locking is just broken under Linux,
especially through NFS. I am not lying : [On the brokenness of File
lockin](http://0pointer.de/blog/projects/locking.html)

## How to install it?
ContaMiner needs CCP4 and MoRDa. You can find them here :
[CCP4: Software for Macromolecular Crystallography](http://www.ccp4.ac.uk)
[Morda - Biomex Solutions](http://www.biomexsolutions.co.uk/morda/)

Download and install them by following the given instructions on the two
websites. It can take a time.

If you need to customise your database of contaminants or the SBATCH options,
see the paragraph "How do I customise the installation" before continuing.

To install ContaMiner and initialise the database of contaminants, just run the
install.sh script. No need to have root permissions. Wait for all the SLURM jobs
to complete. Then you can use contaminer.

## How do I use ContaMiner?
When the installation is complete, you can move the script named `contaminer`
wherever you want on your machine, or even create a symlink. You can, for
example, copy it in
`/usr/local/bin` to make ContaMiner accessible from PATH. Or you can copy it
somewhere else, then add the directory in your PATH.
However, we do not recommand adding the root directory of ContaMiner in your
PATH. Indeed, other scripts which are not directly usefull for the user are
present in this directory.

Afterwards, you can use ContaMiner by giving a data diffraction file in a cif or
mtz format.
> contaminer file.mtz

You can also give a list of contaminants to test (a selection of the
prepared contaminants, __ie__ which are in the data/init/contaminants.xml file)
by giving a txt file with a list of uniprot ID. This file must contain one ID
per line, without blank line (be careful not to add a trailing blank line at
the end of the file), and without comment. Give the name of this file as a
second parameter. This list can also contain relative or absolute paths to
PDB files which will be treated as custom contaminants.
> contaminer file.mtz list.txt

If no txt file is provided, a default selection of contaminants is tested.

ContaMiner will create a directory in your current directory (and not in the
directory of your mtz or cif file), with the same name as your cif
or mtz file. In this directory, you can find different files.

- The data diffraction file you provided
- The list of tested contaminants (the list you provided as second argument, if
  you did)
- One directory per model, per alternative space group containing different
  files from morda\_solve. You basically do not need to explore this directory,
  except if you want to see a specific final model
- results.txt resuming the results of the job

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

## How do I customise the installation?
If you have special needs for SBATCH options or if you want
to customise your database, you can edit the files in data/init directory.
The directory contains different files.

### contaminants.xml
A XML file containing the list of possible contaminants you want to use in your
database, with more information. Each contaminant must fall into a category.
You can add new categories. Each contaminant can have the following fields:
- `uniprot_id` used to retrieve the sequence
- `short_name` (opt) used for some interfaces like django-contaminer
- `long_name` (opt) used for the same purpose
- `organism` (opt) used for the same purpose
- `exact_model` is a boolean used to decide if MoRDa must prepare the models
  from 1 or 3 different templates. Set to true if your contaminant has know
  structures available on the PDB, false otherwise.
- `reference` (opt) contains a pubmed ID to a publication mentioning this
  protein as a contaminant
- `suggestion` (opt) contains the name of someone who suggested this protein as
  a contaminant.

### XXXXXX.fasta
A custom fasta sequence for a contaminant can be provided if you do not want to 
use the full sequence from Uniprot. The name must be XXXXXX.fasta where XXXXXX 
is the uniprot ID of the contaminant listed in the contaminants.xml file.

### prep\_options.slurm
A file containing the SBATCH options ContaMiner will use when submitting the 
preparation tasks to SLURM. You can add, for example,
`#SBATCH --partition=default`
to use a special partition on your cluster, or 
`#SBATCH --mail=you@example.com`
if you want to receive (many) emails to inform you about the state of your
tasks.

### run\_options.slurm
A file containing the SBATCH options ContaMiner will use when submitting the 
standard tasks to SLURM. As before, you can add custom options.
