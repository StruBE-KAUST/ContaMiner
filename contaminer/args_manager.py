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
import yaml

from Bio import SeqIO

from contaminer import config
from contaminer import data as contaminer_data
from contaminer.ccp4 import AltSgList
from contaminer.ccp4 import Cif2Mtz
from contaminer.ccp4 import MordaPrep
from contaminer.ccp4 import MordaSolve
from contaminer.ccp4 import Mtz2Map
from contaminer.ccp4 import MtzDmp

LOG = logging.getLogger(__name__)


class TasksManager():
    """
    Manage the tasks arguments, status and results.

    Attributes
    ----------
    complete: boolean
        True if all tasks are all complete.

    Warning
    -------
    TasksManager.save is NOT thread-safe. It should be used only in the master
    process to avoid racing conditions to the args file when saving.

    """

    def __init__(self):
        # Each job contains 4 keys:
        # * infos: general data about the task:
        #   * uniprot_id: uniprot ID of the contaminant
        #   * is_AF_model: true if the task uses an AlphaFold model
        # * args: arguments to give as is to MordaSolve
        # * results: Dictionnary of results from MordaSolve (None is no result
        # is available.
        # * status: can be new, running or complete.
        self._jobs = []

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
        custom_name = os.path.splitext(os.path.basename(custom_file))[0]
        # Extract sequence
        with open(custom_file, 'r') as pdb_file:
            records = list(SeqIO.parse(pdb_file, 'pdb-atom'))

        assert len(list(records)) == 1
        custom_fasta = custom_name + ".fasta"
        with open(custom_fasta, 'w') as fasta_file:
            fasta_file.write(str(records[0].seq))

        # Prepare morda_prep arguments
        model_dir = os.path.join(parent_dir, custom_name)
        os.mkdir(model_dir)

        # Launch morda_prep
        morda_prep = MordaPrep(
            custom_fasta,
            model_dir,
            1,
            custom_file)
        morda_prep.run()

        return os.path.join(model_dir, "models")

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

        self._generate_jobs(input_file, models, alt_space_groups)

    def _generate_jobs(self, input_file, models, alt_space_groups):
        """
        Generate job items for given parameters and store them in self._jobs.

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
        self._jobs = []
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

                self._generate_jobs_for_contaminant(
                    input_file,
                    contaminant,
                    alt_space_groups,
                )

    def _generate_jobs_for_contaminant(
            self, input_file, contaminant, alt_space_groups):
        """
        Generate job items for a single contaminant.

        This method does the same thing as TasksManager._generate_jobs, but
        generates the items only for a single contaminant.

        """
        # Get number of packs
        nb_packs = self._get_nb_packs(contaminant['uniprot_id'])
        for pack_number in range(1, nb_packs+1):
            for alt_sg in alt_space_groups:
                self._jobs.append({
                    'infos': {
                        'model_name': contaminant['uniprot_id'],
                        'is_AF_model': False,
                        'is_custom_model': False
                    },
                    'args': {
                        'input_file': input_file,
                        'model_dir': os.path.join(
                            config.CONTABASE_DIR,
                            contaminant['uniprot_id'],
                            'models'),
                        'pack_number': pack_number,
                        'space_group': alt_sg
                    },
                    'results': None,
                    'status': 'new'
                })

        # If AlphaFold is available, add this as well.
        if contaminant['alpha_fold']:
            LOG.debug("Add AlphaFold model for %s.", contaminant['uniprot_id'])
            for alt_sg in alt_space_groups:
                self._jobs.append({
                    'infos': {
                        'model_name': contaminant['uniprot_id'],
                        'is_AF_model': True,
                        'is_custom_model': False
                    },
                    'args': {
                        'input_file': input_file,
                        'model_dir': os.path.join(
                            config.CONTABASE_DIR,
                            "AF_" + contaminant['uniprot_id'],
                            'models'),
                        'pack_number': 1,
                        'space_group': alt_sg
                    },
                    'results': None,
                    'status': 'new'
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
            self._jobs.append({
                'infos': {
                    'model_name': model,
                    'is_AF_model': False,
                    'is_custom_model': True
                },
                'args': {
                    'input_file': input_file,
                    'model_dir': model_dir,
                    'pack_number': 1,
                    'space_group': alt_sg
                },
                'results': None,
                'status': 'new'
            })

    def get_arguments(self, rank):
        """
        Return the list of arguments for a task.

        Each item is a dictionary of kwargs to give to morda_solve.

        Parameters
        ----------
        rank: integer
            The rank of the task to get the arguments for.

        Return
        ------
        dictionary
            The list of arguments for morda_solve.

        """
        return copy.deepcopy(self._jobs[rank]['args'])

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

        data = {'jobs': self._jobs}
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

        self._jobs = data['jobs']

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

        mrds = MordaSolve(**arguments)
        mrds.run()

    def compile_results(self):
        """
        Read results of all task instances, and compile the complete ones.

        Warning
        -------
        This method is NOT thread-safe.

        """
        for job in self._jobs:
            if not job['status'] == "complete":
                mrds = MordaSolve(**job['args'])
                try:
                    results = mrds.get_results()
                except FileNotFoundError:
                    job['status'] = "running"
                    continue
                finally:
                    mrds.cleanup()

                results['available_final'] = False
                final_mtz_path = os.path.join(mrds.res_dir, "final.mtz")
                if os.path.exists(final_mtz_path):
                    map_converter = Mtz2Map(final_mtz_path)
                    map_converter.run()
                    results['available_final'] = True

                job['results'] = results
                job['status'] = "complete"

    @property
    def complete(self):
        """Return True if all Tasks are complete. False otherwise."""
        return all([item['status'] == "complete" for job in self._jobs])

    def display_progress(self):
        """Print the task progress."""
        total = len(self._jobs)
        done = len([job for job in self._jobs if job['status'] == "complete"])

        print("%s/%s" % (done, total))

    @property
    def nb_jobs(self):
        """Return the number of jobs."""
        return len(self._jobs)
