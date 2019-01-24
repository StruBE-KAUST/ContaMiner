"""Provide entry point commands for ContaMiner."""

import os
import shutil
import subprocess

from contaminer.args_manager import TasksManager
from contaminer import config


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

    # Number of workers + 1 master
    print("Need %s cores."
          % str(len(tasks_manager.get_arguments()) + 1))


def solve(prep_dir, rank):
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


def submit(prep_dir):
    """
    Submit the job to a scheduler.

    Fill in a template, and use the provided command to submit the script
    to a job scheduler.

    """

    prep_dir = os.path.abspath(prep_dir)
    prep_name = os.path.basename(prep_dir)
    os.chdir(prep_dir)

    nb_procs = _get_number_procs(prep_dir)

    with open(config.TEMPLATE_PATH, 'r') as template_file:
        template_content = template_file.read()

    script_content = template_content.replace(
        "%NB_PROCS%", str(nb_procs)).replace(
            "%PREP_DIR%", prep_dir).replace(
                "%PREP_NAME%", prep_name)

    with open(config.JOB_SCRIPT, 'w') as job_script:
        job_script.write(script_content)

    # Submit newly written script
    command = [config.SCHEDULER_COMMAND, config.JOB_SCRIPT]
    popen = subprocess.Popen(command,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    stdout, stderr = popen.communicate()
    print(stdout.decode('UTF-8'))


def display(prep_dir):
    """
    Compile all results of a job into a the tasks file.

    Consult each task, retrieve the results if available, and write all
    of them in the tasks.json file, then display the content of the file.

    """
    task_manager = TasksManager()
    save_file = os.path.join(prep_dir, config.ARGS_FILENAME)
    task_manager.load(save_file)
    task_manager.compile_results()
    task_manager.save(save_file)
    with open(save_file, 'r') as results:
        print(results.read())


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
    args_list = tasks_manager.get_arguments()
    return len(args_list) + 1
