"""Provide wrappers for CCP4 tools and MoRDa."""

import os
import subprocess

from contaminer import config


class Morda():
    """Wrapper to execute MoRDa."""

    def __init__(self, tool, *args, config=None):
        """Store tool and args."""
        if tool is "solve" or "prep":
            self.tool = tool
        else:
            raise ValueError("tool can be \"solve\" or \"prep\".")

        self.tool = tool
        self.args = args
        self.config = config

    def run(self):
        """Build command line, then launch MoRDa with the args from init."""
        command_line = self.parse_args()
        popen = subprocess.Popen(command_line, stdout=subprocess.PIPE)
        popen.wait()
        output = popen.stdout.read()
        return output

    def parse_args(self):
        """Build command line according to config and given args."""
        user_config = config.UserConfig(self.config).load()
        morda_path = os.path.join(
            user_config['PATH']['morda'],
            'morda_' + self.tool)

        command_line = [morda_path]
        command_line.extend(self.args)

        return command_line
