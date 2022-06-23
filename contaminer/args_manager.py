"""
Provide the tools to manage the list of arguments.

Classes
-------
TasksManager
    Use this class to create the list of arguments, get the parameters for
    a job, ...

"""

import copy
from importlib import resources
import json
import logging
import os
import shutil
import yaml

from contaminer import config
from contaminer import data as contaminer_data
from contaminer.ccp4 import AltSgList
from contaminer.ccp4 import Cif2Mtz
from contaminer.ccp4 import MordaSolve
from contaminer.ccp4 import Mtz2Map
from contaminer.ccp4 import MtzDmp
from contaminer.data.custom_template import XML_TEMPLATE

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
        Return the list of arguments as a list. Each item is a dictionary
        of kwargs to give to morda_solve.

    update
        Update the status of one or more jobs and optionaly add results.

    Warning
    -------
    TasksManager.save is NOT thread-safe. It should be used only in the master
    process to avoid racing conditions to the args file when saving.

    """

    def __init__(self):
        self._args = []
        self._results = []
        self._status = []
        self._mrds = None

    @staticmethod
    def _get_nb_packs(model):
        """
        Get the number of packs available for the model.

        Parameters
        ----------
        model: string
            The PDB ID of the prepared model.

        Return
        ------
        int
            The number of packs available for this model.

        """
        pack_file_path = os.path.join(config.CONTABASE_DIR, model, 'nbpacks')
        with open(pack_file_path) as pack_file:
            str_nb_packs = pack_file.read()

        nb_packs = int(str_nb_packs)
        LOG.debug("Get %s packs for model %s.", nb_packs, model)
        return nb_packs

    @staticmethod
    def _prepare_custom_dir(parent_dir, custom_file):
        """
        Create the directory to use a user-provided PDB model.

        Parameters
        ----------
        parent_dir: string
            Absolute path to the working directory.

        custom_file: string
            Absolute path to the user-provided PDB model.

        Return
        ------
        string
            The absolute path to the created model directory.

        """
        filename = os.path.basename(custom_file)
        model_name, _ = os.path.splitext(filename)
        model_dir = os.path.join(parent_dir, model_name)
        os.mkdir(model_dir)

        # Write XML file
        xml_content = XML_TEMPLATE.replace(
            "%PDB_CODE%", model_name).replace(
                "%FILE_NAME%", filename)

        xml_path = os.path.join(model_dir, "model_prep.xml")
        with open(xml_path, 'w') as xml_file:
            xml_file.write(xml_content)

        # Copy PDB file to proper location
        shutil.copy(custom_file, model_dir)

        return model_dir

    def create(self, input_file, models=None):
        """
        Create the list of arguments for morda_solve.

        Parameters
        ----------
        input_file: string
            The path to the input file to give as is to morda_solve.

        models: list(string)
            The list of contaminants to try to put in the mtz_file.
            If a model name finishes by .pdb, do not search the ContaBase, but
            use the model name as custom model path.

        """
        LOG.info("Create arguments for %s, %s.", input_file, models)
        # Have an MTZ file to get the space group. If the input_file is already
        # in MTZ format, this step does nothing.
        cif2mtz_task = Cif2Mtz(input_file)
        cif2mtz_task.run()
        mtz_file = cif2mtz_task.get_output_file()
        LOG.debug("mtz_file: %s.", mtz_file)

        # Get space group.
        mtz_dmp_task = MtzDmp(mtz_file)
        mtz_dmp_task.run()
        input_space_group = mtz_dmp_task.get_space_group()
        LOG.debug("Input space group: %s.", input_space_group)

        # Get alternate space groups.
        alt_sg_task = AltSgList(input_space_group)
        alt_sg_task.run()
        alt_space_groups = alt_sg_task.get_alt_space_groups()
        LOG.debug("Alt space groups: %s.", alt_space_groups)

        self._generate_args(input_file, models, alt_space_groups)
        self._results = [None for i in self._args]
        self._status = ["new" for i in self._args]

    def _generate_args(self, input_file, models, alt_space_groups):
        """
        Generate arguments for given parameters and store them in self._args.

        This method does the same thing as TasksManager.create, but takes the
        list of alternative space groups as additional argument.

        input_file: string
            The path to the input file to give as is to morda_solve.

        models: list(string)
            The list of contaminants to try to put in the mtz_file.
            If a model name finishes by .pdb, do not search the ContaBase, but
            use the model name as custom model path.

        alt_space_groups: list(sting)
            The alternative space groups in the same class as the space group
            from the input_file.

        """
        # Load ContaBase as flat list of contaminants.
        contabase_yaml = yaml.safe_load(
            resources.read_text(contaminer_data, "contabase.yaml")
        )['contabase']
        contaminants = []
        for category in contabase_yaml:
            contaminants.extend(category['contaminants'])

        # Build arguments list.
        self._args = []
        for model in models:
            if ".pdb" in model:
                self._generate_args_for_custom(
                    input_file,
                    model,
                    alt_space_groups
                )
            else:
                # Get contaminant information from ContaBase.
                contaminant = [
                    item
                    for item in contaminants
                    if item['uniprot_id'] == model
                ][0]

                self._generate_args_for_contaminant(
                    input_file,
                    contaminant,
                    alt_space_groups,
                )

    def _generate_args_for_contaminant(
            self, input_file, contaminant, alt_space_groups):
        """
        Generate arguments for a single contaminant.

        This method does the same thing as TasksManager._generate_args, but
        generates the arguments only for a single contaminant.

        """
        # Get number of packs
        nb_packs = self._get_nb_packs(contaminant['uniprot_id'])
        for pack_number in range(1, nb_packs+1):
            for alt_sg in alt_space_groups:
                self._args.append({
                    'input_file': input_file,
                    'model_dir': os.path.join(
                        config.CONTABASE_DIR,
                        contaminant['uniprot_id'],
                        'models'),
                    'pack_number': pack_number,
                    'space_group': alt_sg
                })

        # If AlphaFold is available, add this as well.
        if contaminant['alpha_fold']:
            LOG.debug("Add AlphaFold model for %s.", contaminant['uniprot_id'])
            for alt_sg in alt_space_groups:
                self._args.append({
                    'input_file': input_file,
                    'model_dir': os.path.join(
                        config.CONTABASE_DIR,
                        "AF_" + contaminant['uniprot_id'],
                        'models'),
                    'pack_number': 1,
                    'space_group': alt_sg
                })

    def _generate_args_for_custom(self, input_file, model, alt_space_groups):
        """
        Generate arguments for a single custom model.

        This method does the same thing as TasksManager._generate_args, but
        generates the arguments only for a single custom model.

        """
        if not os.path.isfile(model):
            raise FileNotFoundError(model)

        # Custom model
        model_dir = self._prepare_custom_dir(os.getcwd(), model)
        for alt_sg in alt_space_groups:
            self._args.append({
                'input_file': input_file,
                'model_dir': model_dir,
                'pack_number': 1,
                'space_group': alt_sg
            })

    def get_arguments(self, rank=None):
        """
        Return the list of arguments for some tasks.

        Each item is a dictionary of kwargs to give to morda_solve.

        Parameters
        ----------
        rank: integer
            The rank of the task to get the arguments for. By default, return
            all arguments.

        Return
        ------
        list(dictionary)
            The list of arguments for morda_solve.

        """
        if isinstance(rank, int):
            return copy.deepcopy(self._args[rank])

        return copy.deepcopy(self._args)

    def save(self, save_filepath):
        """
        Save the list of arguments in a file.

        Dump the arguments in json format in a file located in filepath.

        Parameters
        ----------
        save_filepath: string
            Path to the save file to write.

        Warning
        -------
        This method is NOT thread-safe. It can lead to race conditions when
        writing the save file.

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

    def run(self, prep_dir, rank):
        """
        Start the process of given rank.

        Parameters
        ----------
        prep_dir: string
            Path to the directory generated during the prepare step.

        ranks: integer
            The rank of the current process.

        """
        os.chdir(prep_dir)

        # Load args.
        tasks_manager = TasksManager()
        tasks_manager.load(config.ARGS_FILENAME)

        arguments = tasks_manager.get_arguments(rank)

        self._mrds = MordaSolve(**arguments)
        self._mrds.run()

    def compile_results(self):
        """
        Read results of all task instances, and compile the complete ones.

        Warning
        -------
        This method is NOT thread-safe.

        """
        for index, arguments in enumerate(self._args):
            if not self._status[index] == "complete":
                self._mrds = MordaSolve(**arguments)
                try:
                    results = self._mrds.get_results()
                except FileNotFoundError:
                    self.update(index, status="running")
                    self._mrds.cleanup()
                    continue

                self._mrds.cleanup()
                results['available_final'] = False
                final_mtz_path = os.path.join(self._mrds.res_dir, "final.mtz")
                if os.path.exists(final_mtz_path):
                    map_converter = Mtz2Map(final_mtz_path)
                    map_converter.run()
                    results['available_final'] = True

                self.update(index, results=results, status="complete")

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
