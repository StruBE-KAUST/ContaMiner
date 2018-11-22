"""Provide entry point commands for ContaMiner."""

import os
import shutil
import subprocess
import sys
import time
from mpi4py import MPI

from contaminer.args_manager import CONTABASE_DIR
from contaminer.args_manager import TasksManager
from contaminer.ccp4 import MordaSolve
from contaminer.ccp4 import Mtz2Map

# Configuration
MASTER_RANK = 0
MRD_RESULTS_TAG = 11
ARGS_FILENAME = "tasks.json"
TEMPLATE_PATH = os.path.expanduser("~/.contaminer/job_template.sh")
SCHEDULER_COMMAND = "sbatch"
JOB_SCRIPT = "solve.sbatch"

# Const par process
MPI_COMM = MPI.COMM_WORLD
MPI_SIZE = MPI_COMM.Get_size()
MPI_RANK= MPI_COMM.Get_rank()


def prepare(diffraction_file, models):
    """
    Prepare the arguments file and give the number of processes needed.

    Parameters
    ----------
    diffraction_file: string
        Path to MTZ or CIF file

    models: list(string)
        List of contaminants to test with diffraction file.

    """

    # Convert models to real list
    if models == ["all"]:
        models = _get_all_models()

    # Create working directory
    file_name = os.path.basename(diffraction_file)
    dir_name = os.path.splitext(file_name)[0]
    os.mkdir(dir_name)

    diffraction_file = os.path.abspath(diffraction_file)
    os.chdir(dir_name)
    shutil.copyfile(diffraction_file, file_name)

    tasks_manager = TasksManager()
    tasks_manager.create(file_name, models)
    tasks_manager.save(ARGS_FILENAME)

    # Number of workers + 1 master
    print("Need %s processes."
          % str(len(tasks_manager.get_arguments()) + 1))


def solve(prep_dir):
    """
    Run the morda_solve processes for the given arguments file.

    Parameters
    ----------
    prep_dir: string
        Path to the directory generated during the prepare step.

    """

    os.chdir(prep_dir)

    args_list = None
    # Load args on master rank.
    if MPI_RANK == MASTER_RANK:
        tasks_manager = TasksManager()
        tasks_manager.load(ARGS_FILENAME)
        args_list = tasks_manager.get_arguments()

        # Add an empty space for master as it does not need args.
        args_list.insert(MASTER_RANK, None)

        if MPI_SIZE < len(args_list):
            print("Not enough MPI sockets", file=sys.stderr)
            MPI_COMM.Abort(1)

        # Change tasks status to "running".
        tasks_manager.update(*range(MPI_SIZE-1), status="running")

    # Send args to all ranks.
    arguments = MPI_COMM.scatter(args_list, root=MASTER_RANK)

    # Compute on all worker ranks.
    if MPI_RANK != MASTER_RANK:
        ranked_results = _run(arguments)
        # Send results tag = MRD_RESULTS_TAG
        MPI_COMM.send(ranked_results, dest=MASTER_RANK, tag=MRD_RESULTS_TAG)

    # Receive results on rank #0
    else:
        tasks_manager.display_progress()
        while not tasks_manager.complete:
            # Get results sent on tag = MRD_RESULTS_TAG a few lines before.
            new_result = MPI_COMM.recv(
                source=MPI.ANY_SOURCE, tag=MRD_RESULTS_TAG)

            # Convert rank to array index
            index = new_result['rank']
            if index > MASTER_RANK:
                index -= 1

            tasks_manager.update(
                index,
                results=new_result['results'],
                status="complete")
            tasks_manager.display_progress()
            tasks_manager.save(ARGS_FILENAME)

def submit(prep_dir):
    """
    Submit the job to a scheduler.

    Fill in a template, and use the provided command to submit the script
    to a job scheduler.

    """

    prep_dir = os.path.abspath(prep_dir)
    os.chdir(prep_dir)

    nb_procs = _get_number_procs(prep_dir)

    with open(TEMPLATE_PATH, 'r') as template_file:
        template_content = template_file.read()

    script_content = template_content.replace(
        "%NB_PROCS%", str(nb_procs)).replace(
            "%PREP_DIR%", prep_dir)

    with open(JOB_SCRIPT, 'w') as job_script:
        job_script.write(script_content)

    # Submit newly written script
    command = [SCHEDULER_COMMAND, JOB_SCRIPT]
    popen = subprocess.Popen(command,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    stdout, stderr = popen.communicate()
    print(stdout.decode('UTF-8'))

def _get_all_models():
    """
    Return the list of all models available in the ContaBase.

    Return
    ------
    list(string)
        List of contaminants in the ContaBase

    """
    return os.listdir(CONTABASE_DIR)

def _run(arguments):
    """
    Run one instance of morda_solve, then post-process.

    Parameters
    ----------
    arguments: dictionary
        The arguments to give to MordaSolve.

    Return
    ------
    dictionary
        The results to send back to the master process.

    """
    mrds = MordaSolve(**arguments)
    mrds.run()
    results = mrds.get_results()
    results['available_final'] = False
    ranked_results = {
        'rank': MPI_RANK,
        'results': results
    }

    final_mtz_path = os.path.join(mrds.res_dir, "final.mtz")
    if os.path.exists(final_mtz_path):
        map_converter = Mtz2Map(final_mtz_path)
        map_converter.run()
        results['available_final'] = True
    
    return ranked_results

def _get_number_procs(prep_dir):
    """
    Return the number of processes required to run the task.

    Return
    ------
    integer
        The number of processes required to run the task.

    """
    os.chdir(prep_dir)

    tasks_manager = TasksManager()
    tasks_manager.load(ARGS_FILENAME)
    args_list = tasks_manager.get_arguments()
    return len(args_list) + 1
