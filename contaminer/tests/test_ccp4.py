"""This module tests ccp4.py."""

from unittest import TestCase

from contaminer.ccp4 import Morda
from contaminer.ccp4 import MordaPrep
from contaminer.ccp4 import MordaSolve


class MordaTest(TestCase):
    """Test ccp4.Morda class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        command_line = Morda('prep', '-s', 'fasta.seq')._build_command()
        self.assertEqual(command_line, ['morda_prep', '-s', 'fasta.seq'])


class MordaPrepTest(TestCase):
    """Test ccp4.MordaPrep class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        command_line = MordaPrep("fasta.seq", 3)._build_command()
        self.assertEqual(command_line,
                         ['morda_prep', '-s', 'fasta.seq', '-n', '3'])


class MordaSolveTest(TestCase):
    """Test ccp4.MordaSolve class."""

    def test_build_command(self):
        """Test if parse args gives proper command."""
        morda_solve = MordaSolve("mtz_file", "model_dir", 3, "P-1-1-1")
        command_line = morda_solve._build_command()
        self.assertEqual(command_line,
                         ['morda_solve', '-f', 'mtz_file', '-m', 'model_dir',
                          '-p', 3, '-sg', 'P-1-1-1'])
