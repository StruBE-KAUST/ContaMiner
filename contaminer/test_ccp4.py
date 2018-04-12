"""This module tests ccp4.py."""

import os
import tempfile
import shutil
import unittest

import contaminer
from contaminer.ccp4 import Morda


class MordaTest(unittest.TestCase):
    """Test ccp4.Morda class."""

    def setUp(self):
        """Change $HOME directory to tmp directory."""
        self.home_dir = tempfile.mkdtemp()
        self.home_dir_orig = os.environ['HOME']
        os.environ['HOME'] = self.home_dir

    def tearDown(self):
        """Remove test $HOME directory."""
        shutil.rmtree(self.home_dir)
        os.environ['HOME'] = self.home_dir_orig

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        config_path = os.path.join(
            os.path.dirname(contaminer.__file__),
            'test_config',
            'config1.ini')
        command_line = Morda('prep', '-s', 'fasta.seq',
                             config=config_path).parse_args()
        self.assertEqual(
            command_line,
            ['/opt/morda/morda_prep', '-s', 'fasta.seq'])
