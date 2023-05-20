"""Provide entry point commands for ContaMiner."""

from importlib import resources
import json
import logging
import os
import shutil
import subprocess
from urllib.request import urlretrieve
import yaml

from contaminer.args_manager import TasksManager
from contaminer import config
from contaminer import data as contaminer_data
from contaminer.ccp4 import MordaPrep


LOG = logging.getLogger(__name__)


def _get_all_contaminants():
    """
    Return a flat list of contaminants in the ContaBase.

    The contaminants are not sorted in categories, but each item (contaminant)
    in the list contains details about the contaminant.

    """
    contabase_text = resources.read_text(contaminer_data, "contabase.yaml")
    contabase_yaml = yaml.safe_load(contabase_text)['contabase']
    contaminants = []
    for category in contabase_yaml:
        contaminants.extend(category['contaminants'])

    LOG.debug("%s contaminants found.", len(contaminants))
    return contaminants


def init():
    """
    Initialize the ContaBase.

    Create the ContaBase directory structure, launches the morda_prep
    processes, and compile results for ContaMiner.

    """
    # Parse data file
    LOG.info("Reading ContaBase.")
    contaminants = _get_all_contaminants()

    # Create contabase directories
    contabase_dir = config.CONTABASE_DIR
    try:
        os.mkdir(contabase_dir)
    except FileExistsError:
        LOG.critical("Contabase directory %s already exists. Stopping here.",
                     contabase_dir)
        raise

    for contaminant in contaminants:
        LOG.info("Creating model directory for contaminant %s.",
                 contaminant['uniprot_id'])
        _create_model_dir(contaminant)

        # For some models, add AlphaFold model.
        if contaminant['alpha_fold']:
            _create_model_dir(contaminant, alpha_model=True)

    # Prepare job script
    _create_prepare_job_script(contaminants)

    # Submit newly written script
    LOG.info("Starting preparation job.")
    job_script_path = os.path.join(
        config.CONTABASE_DIR,
        config.JOB_SCRIPT)
    command = [config.SCHEDULER_COMMAND, job_script_path]
    popen = subprocess.Popen(command,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    stdout, stderr = popen.communicate()
    if stdout:
        LOG.info(stdout.decode('UTF-8'))
    LOG.info(("Depending on your job template, the ContaBase may still be "
              "initializing. Please check check the initialization status "
              "with `contaminer status` before submitting a solve task."))


def _create_model_dir(contaminant, alpha_model=False):
    """
    Create the directory where the information for a contaminants are stored.

    Create the directory itself, write or download the sequence, and
    if required, download the PDB file from AlphaFold.

    """
    contabase_dir = config.CONTABASE_DIR
    uniprot_id = contaminant['uniprot_id']
    sequence = contaminant.get("sequence", None)
    if alpha_model:
        model_dir = os.path.join(contabase_dir, "AF_" + uniprot_id)
    else:
        model_dir = os.path.join(contabase_dir, uniprot_id)

    # Create ContaBase structure
    os.mkdir(model_dir)

    # Download or create fasta file
    sequence_file_path = os.path.join(model_dir, "sequence.fasta")
    if sequence:
        with open(sequence_file_path, 'w') as sequence_file:
            sequence_file.write('>lcl|%s' % uniprot_id)
            sequence_file.write(sequence)
    else:
        fasta_url = "http://www.uniprot.org/uniprot/%s.fasta" % uniprot_id
        urlretrieve(fasta_url, sequence_file_path)

    if alpha_model:
        model_url = "https://alphafold.ebi.ac.uk/files/AF-%s-F1-model_v2.pdb" \
            % uniprot_id
        model_file_path = os.path.join(model_dir, "AF_model.pdb")
        urlretrieve(model_url, model_file_path)


def _create_prepare_job_script(contaminants):
    """
    Render a job template to submit preparation tasks to a scheduler.

    Read the job template, replace patterns with generated values, and
    write the resulting script.

    """
    nb_procs = len(contaminants)
    nb_procs += len([contaminant
                     for contaminant in contaminants
                     if contaminant['alpha_fold']])

    with open(config.JOB_TEMPLATE_PATH, 'r') as template_file:
        script_content = template_file.read()
    replacement_patterns = {
        "%NB_PROCS%": str(nb_procs),
        "%MIN_ARRAY%": str(0),
        "%MAX_ARRAY%": str(nb_procs-1),
        "%PREP_NAME%": "ContaBase_init",
        "%PREP_DIR%": "",
        "%COMMAND%": "init-task",
    }
    for pattern, value in replacement_patterns.items():
        script_content = script_content.replace(pattern, value)
    job_script_path = os.path.join(
        config.CONTABASE_DIR,
        config.JOB_SCRIPT)
    with open(job_script_path, 'w') as job_script:
        job_script.write(script_content)


def init_task(rank):
    """
    Run the morda_prep process for the given rank.

    Parameters
    ----------
    rank: integer
        Rank of the process to run.

    """
    # Parse data file,
    LOG.info("Reading ContaBase.")
    contaminants = _get_all_contaminants()

    # Flatten models list.
    models = []
    for contaminant in contaminants:
        models.append(
            {
                'model_name': contaminant['uniprot_id'],
                'nb_homologous': 1 if contaminant['exact_model'] else 3
            }
        )
        if contaminant['alpha_fold']:
            models.append(
                {
                    'model_name': "AF_" + contaminant['uniprot_id'],
                    'nb_homologous': 1,
                    'pdb_model': "AF_model.pdb"
                }
            )
    LOG.debug("Found %s models.", len(models))

    current_model = models[rank]
    destination = os.path.join(
        config.CONTABASE_DIR,
        current_model['model_name'])
    fasta_path = os.path.join(destination, "sequence.fasta")

    LOG.info("Running morda_prep for model %s.", current_model['model_name'])
    if "pdb_model" in current_model:
        pdb_path = os.path.join(destination, current_model['pdb_model'])
        morda_prep = MordaPrep(
            fasta_path,
            destination,
            current_model['nb_homologous'],
            pdb_path)
        morda_prep.run()
    else:
        morda_prep = MordaPrep(
            fasta_path,
            destination,
            current_model['nb_homologous'])
        morda_prep.run()

    # Save number of packs
    nbpacks = morda_prep.get_nbpacks()
    LOG.debug("nbpacks: %s", nbpacks)
    nbpacks_path = os.path.join(destination, "nbpacks")
    LOG.debug("nbpacks path: %s", nbpacks_path)
    with open(nbpacks_path, 'w') as nbpacks_file:
        nbpacks_file.write("%s\n" % str(nbpacks))

    # Remove temporary directories
    morda_prep.cleanup()


def _is_contabase_ready():
    """
    Return True if the ContaBase initialization is complete.

    Return False otherwise.

    """
    contabase_dir = config.CONTABASE_DIR

    if not os.path.isdir(contabase_dir):
        return False

    contaminants = _get_all_contaminants()
    for contaminant in contaminants:
        nbpacks_path = os.path.join(
            contabase_dir,
            contaminant['uniprot_id'],
            "nbpacks")
        if not os.path.isfile(nbpacks_path):
            return False

        if contaminant['alpha_fold']:
            nbpacks_path = os.path.join(
                contabase_dir,
                "AF_" + contaminant['uniprot_id'],
                "nbpacks")
            if not os.path.isfile(nbpacks_path):
                return False

    return True


def init_status():
    """
    Show the status of ContaBase initialization.

    Init status can be:
        * Absent: there is no sign of life of any local ContaBase
        * Initializing: the ContaBase has been created, and the models are
    being computed now.
        * Ready: all preparation steps are complete, and you can run a
    `contaminer solve`
        * Corrupted: the folder is present, but the content does not seem
    correct. It's probably a good idea to remove the ContaBase and re-create it.

    """
    contabase_dir = config.CONTABASE_DIR

    if not os.path.isdir(contabase_dir):
        print("ContaBase is: Absent.")
        print("You can create it by running `contaminer init`.")
        return

    try:
        contaminants = _get_all_contaminants()
        for contaminant in contaminants:
            nbpacks_path = os.path.join(
                contabase_dir,
                contaminant['uniprot_id'],
                "nbpacks")
            if not os.path.isfile(nbpacks_path):
                print("ContaBase is: Initializing.")
                print("Please wait for the initialization to complete.")
                return

            if contaminant['alpha_fold']:
                nbpacks_path = os.path.join(
                    contabase_dir,
                    "AF_" + contaminant['uniprot_id'],
                    "nbpacks")
                if not os.path.isfile(nbpacks_path):
                    print("Contabase is: Initializing")
                    print("Please wait for the initialization to complete.")
                    return

    # A bit too large, but we need to capture all IO related errors.
    except OSError:
        print("ContaBase is: Corrupted.")
        print("Please remove the directory, and run `contaminer init`.")
        return

    print("ContaBase is: Ready.")


def _prepare_solve(diffraction_file, models):
    """
    Prepare the arguments file and give the number of processes needed.

    Parameters
    ----------
    diffraction_file: string
        Path to MTZ or CIF file

    models: list(string)
        List of contaminants to test with diffraction file.

    """
    # Convert relative path to custom models in absolute
    for index in range(len(models)):
        if ".pdb" in models[index]:
            models[index] = os.path.join(
                os.getcwd(),
                models[index])

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
    tasks_manager.save(config.ARGS_FILENAME)

    # Return path of the generated directory
    return os.getcwd()


def _submit(prep_dir):
    """
    Submit the job to a scheduler.

    Fill in a template, and use the provided command to submit the script
    to a job scheduler.

    """
    prep_dir = os.path.abspath(prep_dir)
    prep_name = os.path.basename(prep_dir)
    os.chdir(prep_dir)

    nb_procs = _get_number_procs(prep_dir)

    with open(config.JOB_TEMPLATE_PATH, 'r') as template_file:
        script_content = template_file.read()

    replacement_patterns = {
        "%NB_PROCS%": str(nb_procs),
        "%PREP_NAME%": prep_name,
        "%MIN_ARRAY%": str(0),
        "%MAX_ARRAY%": str(nb_procs-1),
        "%COMMAND%": "solve-task " + prep_dir,
    }

    for pattern, value in replacement_patterns.items():
        script_content = script_content.replace(pattern, value)

    with open(config.JOB_SCRIPT, 'w') as job_script:
        job_script.write(script_content)

    # Submit newly written script
    command = [config.SCHEDULER_COMMAND, config.JOB_SCRIPT]
    popen = subprocess.Popen(command,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    stdout, stderr = popen.communicate()


def solve(diffraction_file, models):
    """
    Try to find a contaminant matchgin the diffraction file.

    Prepare the arguments file and all other files, generate the script from
    a template, and submit the job script to a scheduler.

    """
    if not _is_contabase_ready():
        raise RuntimeError("ContaBase is not ready yet.")

    prep_dir = _prepare_solve(diffraction_file, models)
    _submit(prep_dir)


def solve_task(prep_dir, rank):
    """
    Run the morda_solve processes for the given arguments file.

    Parameters
    ----------
    prep_dir: string
        Path to the directory generated during the prepare step.

    rank: integer
        Rank of the process to run.

    """
    task_manager = TasksManager()
    task_manager.load(os.path.join(prep_dir, config.ARGS_FILENAME))
    task_manager.run(prep_dir, rank)


def solve_status(prep_dir):
    """
    Display the status of a job.

    Compile the results into the tasks.json file (same as show_job), and
    display the status of the job. Possible values are:
    * running: if at least one result is missing
    * complete: if all results are available for all combinations of pack/
    space groups

    """
    task_manager = TasksManager()
    os.chdir(prep_dir)
    task_manager.load(config.ARGS_FILENAME)
    task_manager.compile_results()
    task_manager.save(config.ARGS_FILENAME)

    if task_manager.complete:
        print("Job in folder %s is complete." % prep_dir)
    else:
        print("Job in folder %s is running." % prep_dir)


def _get_best_task(tasks):
    """
    Return the task with the best results from the tasks list.

    A task is considered best than another if the "percentage" in the results
    is higher. If the percentage is equal, the task with highest Q factor is
    considered best. If the Q factor is also equal, the first task of the list
    with the highest percentage an Q factor is selected.
    Tasks in running state are not eligible, since no result is available.
    If no task is eligible, return None.

    """
    # Make sure not to work on an emtpy list.
    if not tasks:
        return None

    best_task = None
    for task in tasks:
        if task['status'] == 'complete':
            if not best_task:  # No other data to compare.
                best_task = task
                continue

            # Otherwise, compare with current best task.
            results = task['results']
            best_results = best_task['results']
            if results['percent'] > best_results['percent']:
                best_task = task
            elif results['percent'] == best_results['percent']:
                if results['q_factor'] > best_results['q_factor']:
                    best_task = task

    return best_task


def show_job(prep_dir, summary=False):
    """
    Compile all results of a job into the tasks file.

    Consult each task, retrieve the results if available, and write all
    of them in the tasks.json file, then display the content of the file.

    If summary is set to True, display only the best task per contaminant.
    The best task is selected based on the results of MordaSolve.

    """
    task_manager = TasksManager()
    os.chdir(prep_dir)
    task_manager.load(config.ARGS_FILENAME)
    task_manager.compile_results()
    task_manager.save(config.ARGS_FILENAME)

    if not summary:
        with open(config.ARGS_FILENAME, 'r') as results:
            print(results.read())
    else:
        display = {
            'tasks': []
        }  # Dictionnary to display at the end.

        tasks = task_manager.jobs
        model_names = list(set(
            [task['infos']['model_name'] for task in tasks]
        ))
        for model_name in model_names:
            tasks = [
                task for task in tasks
                if task['infos']['model_name'] == model_name
            ]
            best_task = _get_best_task(tasks)
            display['tasks'].append(best_task)

        print(json.dumps(display))


def _get_all_models():
    """
    Return the list of all models available in the ContaBase.

    Return
    ------
    list(string)
        List of contaminants in the ContaBase

    """
    return os.listdir(config.CONTABASE_DIR)


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
    tasks_manager.load(config.ARGS_FILENAME)
    return tasks_manager.nb_jobs


def show_contabase():
    """
    Return the current ContaBase in YAML format.

    Does not return details about packs and models, but only categories
    and contaminants.

    """
    print(resources.read_text(contaminer_data, "contabase.yaml"))
