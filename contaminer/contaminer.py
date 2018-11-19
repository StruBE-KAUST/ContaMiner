"""Provide entry point commands for ContaMiner."""

import sys
import time
from mpi4py import MPI

from contaminer.args_manager import TasksManager
from contaminer.ccp4 import MordaSolve

MASTER_RANK = 0
MRD_RESULTS_TAG = 11


def prepare(diffraction_file, models):
    """
    Prepare the arguments file and give the number of processes needed.

    Parameters
    ----------
    diffraction_file: string
        Path to MTZ or CIF file

    models: list(string)
        List of contaminants to test with diffraciton file.

    """

    tasks_manager = TasksManager()
    tasks_manager.create(diffraction_file, models)
    tasks_manager.save("args.json")

    # Number of workers + 1 master
    print("Need %s processes."
          % str(len(tasks_manager.get_arguments()) + 1))


def solve(args_file):
    """
    Run the morda_solve processes for the given arguments file.

    Parameters
    ----------
    args_file: string
        Path to the arguments file generated during the prepare step.

    """

    mpi_comm = MPI.COMM_WORLD
    mpi_size = mpi_comm.Get_size()
    mpi_rank = mpi_comm.Get_rank()

    args_list = None
    # Load args on master rank.
    if mpi_rank == MASTER_RANK:
        tasks_manager = TasksManager()
        tasks_manager.load(args_file)
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
        while not tasks_manager.complete:
            tasks_manager.display_progress()

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
            tasks_manager.save("args.json")
