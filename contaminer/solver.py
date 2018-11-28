"""Provide the heavy-lifter running morda_solve and gathering data."""

import os
import sys
from mpi4py import MPI

from contaminer.args_manager import TasksManager
from contaminer.ccp4 import MordaSolve
from contaminer.ccp4 import Mtz2Map
from contaminer.config import *

# Const par process
MPI_COMM = MPI.COMM_WORLD
MPI_SIZE = MPI_COMM.Get_size()
MPI_RANK= MPI_COMM.Get_rank()


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
        tasks_manager.save(ARGS_FILENAME)

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
