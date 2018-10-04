"""This module tests ccp4.py."""

import os
import unittest

from contaminer.ccp4 import Morda
from contaminer.ccp4 import MordaPrep
from contaminer.ccp4 import MordaSolve


TEST_DIR = os.path.dirname(os.path.realpath(__file__))


def contains(sub_list, complete_list):
    """
    Find a sublist in a larger list.

    If the sublist is found, return the starting position. Return False
    otherwise.

    """
    for i in xrange(len(complete_list) - len(sub_list) + 1):
        for j in xrange(len(sub_list)):
            if complete_list[i+j] != sub_list[j]:
                break
        else:
            return i

    return False


class MordaTest(unittest.TestCase):
    """Test ccp4.Morda class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        command_line = Morda('prep', '-s', 'fasta.seq')._build_command()
        self.assertEqual(command_line, ['morda_prep', '-s', 'fasta.seq'])


class MordaPrepTest(unittest.TestCase):
    """Test ccp4.MordaPrep class."""

    def test_parse_args(self):
        """Test if parse args gives proper command."""
        command_line = MordaPrep("fasta.seq", "output", 3)._build_command()
        self.assertEqual(command_line,
                         ['morda_prep', '-s', 'fasta.seq', '-n', '3'])


class MordaSolveTest(unittest.TestCase):
    """Test ccp4.MordaSolve class."""

    def test_build_command(self):
        """Test if parse args gives proper command."""
        morda_solve = MordaSolve("mtz_file", "model_dir", 3, "P-1-1-1")
        command_line = morda_solve._build_command()

        self.assertEqual(command_line[0], 'morda_solve')
        self.assertTrue(['-f', 'mtz_file'], command_line)
        self.assertTrue(['-m', 'model_dir'], command_line)
        self.assertTrue(['-p', '3'], command_line)
        self.assertTrue(['-sg', 'P-1-1-1'], command_line)

    def test_get_results(self):
        """get_results should return the scores from the results file."""
        os.chdir(os.path.join(TEST_DIR, "data"))
        morda_solve = MordaSolve("5jk4-sf.cif", "models", 1, "P1")
        # morda_solve.run() # Disabled as the dir is provided with the project.
        results = morda_solve.get_results()
        self.assertDictEqual(
            results,
            {
                'r_init': 0.548,
                'rf_init': 0.542,
                'rf_fin': 0.253,
                'r_fin': 0.231,
                'Z_score': 34.067,
                'q_factor': 0.905,
                'percent': 99.0
            })


if __name__ == "__main__":
    unittest.main()
