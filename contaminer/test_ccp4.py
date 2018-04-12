"""This module tests ccp4.py."""

import os
import tempfile
import shutil
import unittest

import contaminer
from contaminer.ccp4 import Morda
from contaminer.ccp4 import MordaPrep
from contaminer.ccp4 import MordaSolve


class MordaTest(unittest.TestCase):
    """Test ccp4.Morda class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        config_path = os.path.join(
            os.path.dirname(contaminer.__file__),
            'test_config',
            'config1.ini')
        command_line = Morda('prep', '-s', 'fasta.seq',
                             config_path=config_path).parse_args()
        self.assertEqual(
            command_line,
            ['/opt/morda/morda_prep', '-s', 'fasta.seq'])


class MordaPrepTest(unittest.TestCase):
    """Test ccp4.MordaPrep class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        config_path = os.path.join(
            os.path.dirname(contaminer.__file__),
            'test_config',
            'config1.ini')
        command_line = MordaPrep("fasta.seq", 3,
                                 config_path=config_path).parse_args()
        self.assertEqual(command_line,
                         ['/opt/morda/morda_prep', '-s', 'fasta.seq', '-n', 3])


class MordaSolveTest(unittest.TestCase):
    """Test ccp4.MordaSolve class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        config_path = os.path.join(
            os.path.dirname(contaminer.__file__),
            'test_config',
            'config1.ini')
        command_line = MordaSolve("mtz_file", "model_dir", 3, "P-1-1-1",
                                  config_path=config_path).parse_args()
        self.assertEqual(command_line,
                         ['/opt/morda/morda_solve', '-f', 'mtz_file', '-m', 'model_dir',
                          '-p', 3, '-sg', 'P-1-1-1'])
