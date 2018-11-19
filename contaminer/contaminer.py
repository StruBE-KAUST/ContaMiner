"""Provide entry point commands for ContaMiner."""

import os
import shutil
import sys
import time
from mpi4py import MPI

from contaminer.args_manager import TasksManager
from contaminer.ccp4 import MordaSolve

MASTER_RANK = 0
MRD_RESULTS_TAG = 11
ARGS_FILENAME = "args.json"


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

    mpi_comm = MPI.COMM_WORLD
    mpi_size = mpi_comm.Get_size()
    mpi_rank = mpi_comm.Get_rank()

    args_list = None
    # Load args on master rank.
    if mpi_rank == MASTER_RANK:
        tasks_manager = TasksManager()
        tasks_manager.load(ARGS_FILENAME)
        args_list = tasks_manager.get_arguments()

        # Add an empty space for master as it does not need args.
        args_list.insert(MASTER_RANK, None)

        if mpi_size < len(args_list):
            print("Not enough MPI sockets", file=sys.stderr)
            mpi_comm.Abort(1)

        # Change tasks status to "running".
        tasks_manager.update(*range(mpi_size-1), status="running")

    # Send args to all ranks.
    arguments = mpi_comm.scatter(args_list, root=MASTER_RANK)

    # Compute on all worker ranks.
    if mpi_rank != MASTER_RANK:
        mrds = MordaSolve(**arguments)
        mrds.run()
        results = mrds.get_results()
        ranked_results = {
            'rank': mpi_rank,
            'results': results
        }
        # Send results tag = MRD_RESULTS_TAG
        mpi_comm.send(ranked_results, dest=MASTER_RANK, tag=MRD_RESULTS_TAG)

    # Receive results on rank #0
    else:
        tasks_manager.display_progress()
        while not tasks_manager.complete:
            # Get results sent on tag = MRD_RESULTS_TAG a few lines before.
            new_result = mpi_comm.recv(
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
