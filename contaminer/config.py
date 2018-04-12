"""Manage configuration of contaminer in user's home directory."""

import configparser
import errno
import os


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

        Try to guess CCP4 and MoRDa installation from environment variable.
        Keep morda_path and ccp4_path empty if not found. user_config.load will
        take care of raising the error for the user.

        """
        # Create directory
        try:
            os.makedirs(os.path.dirname(self.config_path))
        except OSError as err:
            if err.errno != errno.EEXIST:
                raise

        # Build default config
        # TODO: Auto-detect CCP4 and MoRDa paths
        config = configparser.ConfigParser()
        config.add_section('PATH')
        config['PATH']['ccp4'] = ''
        config['PATH']['morda'] = ''

        config.add_section('RUN')
        config['RUN']['loop_on_error'] = 'False'

        # Write file
        with open(self.config_path, 'w') as config_file:
            config.write(config_file)
