"""
Provide the tools to manage the list of arguments.

Classes
-------
TasksManager
    Use this class to create the list of arguments, get the parameters for
    a job, ...

"""

import copy
import json
import logging
import os

from contaminer.ccp4 import AltSgList
from contaminer.ccp4 import Cif2Mtz
from contaminer.ccp4 import MtzDmp
from contaminer.config import *

LOG = logging.getLogger(__name__)


class TasksManager():
    """
    Manage the tasks arguments, status and results.

    Attributes
    ----------
    complete: boolean
        True if all tasks are all complete.

    Methods
    -------
    create
        Create the list, and add the list of tasks parameters.

    save
        Save the list of arguments in a file.

    load
        Load the list of arguments from a file.

    get_arguments
        Return the list of arguments as a list. Each item is a dicitonary
        of kwargs to give to morda_solve.

    update
        Update the status of one or more jobs and optionaly add results.

    Warning
    -------
    This class is NOT thread-safe. It should be used only in the master
    process to avoid racing conditions to the args file when saving.

    """

    def __init__(self):
        self._args = []
        self._results = []
        self._status = []

    @staticmethod
    def _get_nb_packs(model):
        """
        Get the number of packas available for the model.

        Parameters
        ----------
        model: string
            The PDB ID of the prepared model.

        Return
        ------
        int
            The number of packs available for this model.

        """
        pack_file_path = os.path.join(CONTABASE_DIR, model, 'nbpacks')
        with open(pack_file_path) as pack_file:
            str_nb_packs = pack_file.read()

        nb_packs = int(str_nb_packs)
        LOG.debug("Get %s packs for model %s.", nb_packs, model)
        return nb_packs

    def create(self, input_file, models=None):
        """
        Create the list of arguments for morda_solve.

        Parameters
        ----------
        input_file: string
            The path to the input file to give as is to morda_solve.

        models: list(string)
            The list of contaminants to try to put in the mtz_file. If nothing
            if given, use the default list of contaminants.

        """
        LOG.info("Create arguments for %s, %s.", input_file, models)
        # Have an MTZ file to get the space group
        cif2mtz_task = Cif2Mtz(input_file)
        cif2mtz_task.run()
        mtz_file = cif2mtz_task.get_output_file()
        LOG.debug("mtz_file: %s.", mtz_file)

        # Get space group
        mtz_dmp_task = MtzDmp(mtz_file)
        mtz_dmp_task.run()
        input_space_group = mtz_dmp_task.get_space_group()
        LOG.debug("Input space group: %s.", input_space_group)

        # Get alternate space groups
        alt_sg_task = AltSgList(input_space_group)
        alt_sg_task.run()
        alt_space_groups = alt_sg_task.get_alt_space_groups()
        LOG.debug("Alt space groups: %s.", alt_space_groups)

        self._args = []

        # Build arguments
        for model in models:
            # Get number of packs
            nb_packs = self._get_nb_packs(model)

            for pack_number in range(1, nb_packs+1):
                for alt_sg in alt_space_groups:
                    self._args.append({
                        'input_file': input_file,
                        'model_dir': os.path.join(
                            CONTABASE_DIR, model, 'models'),
                        'pack_number': pack_number,
                        'space_group': alt_sg
                    })

        self._results = [None for i in range(len(self._args))]
        self._status = ["new" for i in range(len(self._args))]

    def get_arguments(self):
        """
        Return the list of arguments for the tasks.

        Each item is a dictionary of kwargs to give to morda_solve.

        Return
        ------
        list(dictionary)
            The list of arguments for morda_solve.

        """
        return copy.deepcopy(self._args)

    def save(self, save_filepath):
        """
        Save the list of arguments in a file.

        Dump the arguments in json format in a file located in filepath.

        Parameters
        ----------
        save_filepath: string
            Path to the save file to write.

        """
        LOG.debug("Save arguments to %s.", save_filepath)

        data = {
            'args': self._args,
            'results': self._results,
            'status': self._status
        }
        with open(save_filepath, 'w') as save_file:
            save_file.write(json.dumps(data))

    def load(self, save_filepath):
        """
        Load a list of arguments from a save file.

        Parameters
        ----------
        save_filepath: string
            Path to the save file to load.

        """
        LOG.debug("Load arguments from %s.", save_filepath)
        with open(save_filepath, 'r') as save_file:
            data = json.loads(save_file.read())

        self._args = data['args']
        self._results = data['results']
        self._status = data['status']

    def update(self, *ranks, results=None, status=None):
        """
        Update the status and results for some tasks.

        If given, change the results and status of the selected tasks.

        Parameters
        ----------
        ranks: pack
            The rank of the tasks to update.

        results: dictionary
            The result to set for the given ranks. By default, do not change.

        status: dictionary
            The status to set for the given ranks. By default, do not change.

        """

        for rank in ranks:
            if status:
                self._status[rank] = status
            if results:
                self._results[rank] = results

    @property
    def complete(self):
        """Return True if all Tasks are complete. False otherwise."""
        return all([item == "complete" for item in self._status])

    def display_progress(self):
        """Print the task progress."""
        total = len(self._args)
        done = len([status for status in self._status if status == "complete"])

        print("%s/%s" % (done, total))
