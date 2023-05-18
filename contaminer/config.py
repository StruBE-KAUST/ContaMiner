"""Manage configuration of contaminer in user's home directory."""

import configparser
import errno
from importlib import resources
import os

from contaminer import data as contaminer_data


class UserConfig():
    """
    Manage user configuration present in ~/.contaminer/config.ini.

    Try to load the configuration file. If it does not exist, create a default
    one.

    Attributes
    ----------
    config_path: str
        Path to config file.

    """

    def __init__(self, config_file=None):
        """
        Create config file if it does not exist and store its path.

        Parameters
        ----------
        config_file: str
            Path to the config file to use.

        """
        if config_file:
            self.config_path = config_file
        else:
            self.config_path = os.path.join(
                os.path.expanduser('~'),
                ".contaminer",
                "config.ini")

    def load(self):
        """
        Try to load config file. Create the config file is it does not exist.

        Returns
        -------
        loaded_config: list
            User configuration, parsed with ConfigParser.

        """
        if not os.path.isfile(self.config_path):
            self.write_default_config()

        loaded_config = configparser.ConfigParser()
        loaded_config.read(self.config_path)
        return loaded_config

    def write_default_config(self):
        """
        Write default config file.

        This default config is not complete since paths to MoRDa and CCP4 are
        empty. However, we add a comment to help the user fill in missing
        values.

        """
        # Create directory
        try:
            os.makedirs(os.path.dirname(self.config_path))
        except OSError as err:
            if err.errno != errno.EEXIST:
                raise

        # Build default config
        config = configparser.ConfigParser()
        config.add_section('PATH')
        config['PATH']['ccp4'] = '# Full path to ccp4.setup-sh file.'
        config['PATH']['morda'] = '# Full path to morda_env_sh file.'
        config['PATH']['args_filename'] = "tasks.json"
        with resources.path(contaminer_data, "job_template.sh") as template:
            config['PATH']['job_template_path'] = str(template)
        config['PATH']['scheduler_command'] = "bash"
        config['PATH']['contabase_dir'] = os.path.expanduser(
            "~/.contaminer/ContaBase")

        # Write file
        with open(self.config_path, 'w') as config_file:
            config.write(config_file)

        # Show warning about non complete config.
        print("A new config file has been written at %s. " % self.config_path
              + "This file is not complete. Please edit it manually to "
              + "update the missing values.")


CONFIG = UserConfig().load()
ARGS_FILENAME = CONFIG['PATH']['args_filename']
JOB_TEMPLATE_PATH = CONFIG['PATH']['job_template_path']
SCHEDULER_COMMAND = CONFIG['PATH']['scheduler_command']
CONTABASE_DIR = CONFIG['PATH']['contabase_dir']

# No need to move that to user config, as it's only used internally
JOB_SCRIPT = "job.sh"
