"""
Provide the tools to manage the list of arguments.

Classes
-------
ArgumentsListManager
    Use this class to create the list of arguments, get the parameters for
    a job, ...

"""

import os

from contaminer.ccp4 import AltSgList
from contaminer.ccp4 import Cif2Mtz
from contaminer.ccp4 import MtzDmp

CONTABASE_DIR = os.path.expanduser("~/.contaminer/ContaBase")


class ArgumentsListManager():
    """
    Get the arguments.

    Methods
    -------
    create
        Create the list, and add the list of tasks parameters.

    """

    def __init__(self):
        self._args_list = []

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
        return nb_packs

    def create(self, input_file, models=None):
        """
        Create the list of arguments for morda_solve.

        Parameters
        ----------
        input_file: string
            The path to the input file to give as is to morda_solve.

        models: list(string)
            The list of models to try to put in the mtz_file. If nothing
            if given, use the default list of contaminants.

        """
        # Have an MTZ file to get the space group
        cif2mtz_task = Cif2Mtz(input_file)
        cif2mtz_task.run()
        mtz_file = cif2mtz_task.get_output_file()

        # Get space group
        mtz_dmp_task = MtzDmp(mtz_file)
        mtz_dmp_task.run()
        input_space_group = mtz_dmp_task.get_space_group()

        # Get alternate space groups
        alt_sg_task = AltSgList(input_space_group)
        alt_sg_task.run()
        alt_space_groups = alt_sg_task.get_alt_space_groups()

        self._args_list = []

        # Build arguments
        for model in models:
            # Get number of packs
            nb_packs = self._get_nb_packs(model)

            for pack_number in range(1, nb_packs+1):
                for alt_sg in alt_space_groups:
                    self._args_list.append({
                        'input_file': input_file,
                        'model_dir': os.path.join(
                            CONTABASE_DIR, model, 'models'),
                        'pack_number': pack_number,
                        'space_group': alt_sg
                    })
