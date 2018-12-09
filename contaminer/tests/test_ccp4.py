"""
Test contaminer.ccp4.

Classes
-------
MordaTest
MordaPrepTest


"""

import os
import unittest

from contaminer.ccp4 import AltSgList
from contaminer.ccp4 import Cif2Mtz
from contaminer.ccp4 import Morda
from contaminer.ccp4 import MordaPrep
from contaminer.ccp4 import MordaSolve
from contaminer.ccp4 import Mtz2Map
from contaminer.ccp4 import MtzDmp


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
        morda_solve = MordaSolve("5jk4-sf.cif", "models", 1, "P 1 21 1")
        # morda_solve.run() # Disabled as the dir is provided with the project.
        results = morda_solve.get_results()
        self.assertDictEqual(
            results,
            {
                'r_init': 0.548,
                'rf_init': 0.552,
                'rf_fin': 0.25,
                'r_fin': 0.235,
                'Z_score': 33.454,
                'q_factor': 0.907,
                'percent': 99.0
            })

    def test_get_no_solution(self):
        """get_results returns scores if morda_solve reports no result."""
        os.chdir(os.path.join(TEST_DIR, "data"))
        morda_solve = MordaSolve("5jk4-sf.cif", "models", 1, "P 1")
        # morda_solve.run() # Disabled as the dir is provided with the project.
        results = morda_solve.get_results()
        self.assertDictEqual(
            results,
            {
                'r_init': 0.0,
                'rf_init': 0.0,
                'rf_fin': 0.0,
                'r_fin': 0.0,
                'Z_score': 0.0,
                'q_factor': 0.0,
                'percent': 0
            })


class MtzDmpTest(unittest.TestCase):
    """Test ccp4.MtzDmp class."""

    def test_get_space_group(self):
        """Running on the example input file gives the expected space group."""
        os.chdir(os.path.join(TEST_DIR, "data"))
        mtzdmp = MtzDmp("5jk4-sf.mtz")
        mtzdmp.run()
        result = mtzdmp.get_space_group()
        self.assertEqual(result, "P 1 21 1")


class AltSgListTest(unittest.TestCase):
    """Test alt_sg_list wrapper."""

    def test_get_alt_space_groups(self):
        """Return expected alternate space groupes."""
        alt_sg_process = AltSgList("P 1 21 1")
        alt_sg_process.run()
        alt_sg = alt_sg_process.get_alt_space_groups()
        self.assertListEqual(
            alt_sg,
            ['P 1 21 1', 'P 1 2 1'])


class Cif2MtzTest(unittest.TestCase):
    """Test cif2mtz wrapper."""

    def test_convert_mtz(self):
        """Properly convert a CIF file."""
        os.chdir(os.path.join(TEST_DIR, "data"))
        cif2mtz_process = Cif2Mtz("5jk4-sf.2.cif")
        cif2mtz_process.run()

        output_file = cif2mtz_process.get_output_file()

        try:
            # Check with MtzDmp
            mtzdmp = MtzDmp(output_file)
            mtzdmp.run()
            space_group = mtzdmp.get_space_group()

            self.assertEqual(space_group, "P 1 21 1")

        finally:
            os.remove(output_file)


class Mtz2MapTest(unittest.TestCase):
    """Test mtz2map wrapper."""

    def test_convert_map(self):
        """Properly convert a MTZ file."""
        os.chdir(os.path.join(TEST_DIR, "data"))
        mtz2map_process = Mtz2Map("5jk4-sf.mtz")

        mtz2map_process.run()

        output_files = mtz2map_process.get_output_files()

        try:
            self.assertEqual(
                output_files,
                ("5jk4-sf.map", "5jk4-sf_diff.map"))
            for file in output_files:
                self.assertTrue(os.path.isfile(file))
        finally:
            for file in output_files:
                os.remove(file)


if __name__ == "__main__":
    unittest.main()
