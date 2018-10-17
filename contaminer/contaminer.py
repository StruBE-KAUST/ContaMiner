"""Provide entry point commands for ContaMiner."""

from contaminer.args_manager import ArgumentsListManager


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

    arguments_manager = ArgumentsListManager()
    arguments_manager.create(diffraction_file, models)
    arguments_manager.save("args.json")

    print("Need %s processes." % len(arguments_manager._args_list))
