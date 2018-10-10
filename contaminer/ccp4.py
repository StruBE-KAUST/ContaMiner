"""
Provide wrappers for CCP4 tools and MoRDa.

Classes
-------
Morda
MordaPrep
MordaSolve

"""

import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile
from xml.etree import ElementTree

LOGGER = logging.getLogger(__name__)


class Morda():
    """
    Wrapper to execute MoRDa tools.

    This class is not expected to be used out of this module.
    For an easier to use wrapper, see MordaPrep and MordaSolve.

    Attributes
    ----------
    tool: string
        Either "prep" or "solve" to run "morda_prep" or "morda_solve".

    args: tuple(string)
        Arguments to give to the Morda tool.
        Eg: ('-f', '/path/to/file', '-p', '3')

    See Also
    --------
    contaminer.ccp4.MordaSolve
    contaminer.ccp4.MordaPrep

    """

    def __init__(self, tool, *args):
        """Store tool and args."""
        if tool in ["solve", "prep"]:
            self.tool = tool
        else:
            raise ValueError("tool can be \"solve\" or \"prep\".")

        self.tool = tool
        self.args = map(str, args)
        self.output = None

    def run(self):
        """Build command line and launch MoRDa with the args from init."""
        # Build command line
        command_line = self._build_command()

        # Run MoRDa
        LOGGER.debug("Run line: %s", command_line)
        try:
            popen = subprocess.Popen(command_line,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
        except FileNotFoundError:
            print("Please source morda_env_sh before using ContaMiner.",
                  file=sys.stderr)
            raise RuntimeError("MoRDa tools cannot be found.")

        stdout, stderr = popen.communicate()

        if popen.returncode != 0:
            print("Call to %s failed." % 'morda_' + self.tool,
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            print("Output: \n%s" % stdout.decode('UTF-8'),
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            print("Error: \n%s" % stderr.decode('UTF-8'),
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            raise RuntimeError("Call to morda_%s failed." % self.tool)

        self.output = stdout.decode('UTF-8')

    def _build_command(self):
        """
        Build command line according to config and given args.

        Return
        ------
        list(string)
            The full command to give to the shell to run the tool.

        """
        tool_path = os.path.join('morda_' + self.tool)
        command_line = [tool_path]
        command_line.extend(self.args)

        return command_line

    def cleanup(self):
        """Remove temporary directories and other useless stuff."""
        raise NotImplementedError("I don't know what to do...")


class MordaPrep(Morda):
    """
    Wrapper to execute morda_prep.

    Interface which calls the Morda wrapper with the proper arguments for
    morda_prep.

    """

    def __init__(self, fasta, destination, nb_homologous=1):
        args = ["-s", fasta]
        args.extend(["-n", str(nb_homologous)])
        args.append('--alt')

        fasta_name = os.path.basename(os.path.splitext(fasta)[0])
        models_dir = os.path.join(destination, fasta_name)
        args.extend(["-d", models_dir])

        self._temp_dir = tempfile.mkdtemp()
        output_dir = os.path.join(self._temp_dir, "out_prep")
        scratch_dir = os.path.join(self._temp_dir, "scr_prep")
        args.extend(['-po', output_dir])
        args.extend(['-ps', scratch_dir])

        super().__init__("prep", "-s", fasta, "-n", str(nb_homologous))

    def cleanup(self):
        """Remove temporary directory."""
        shutil.rmtree(self._temp_dir)


class MordaSolve(Morda):
    """
    Wrapper to execute morda_solve.

    Interface which calls the Morda wrapper with the proper arguments for
    morda_solve.

    """

    def __init__(self, mtz_file, model_dir, pack_number, space_group):
        space_group = space_group.replace('-', ' ')
        dashed_space_group = space_group.replace(' ', '-')
        args = ["solve", '-f', mtz_file, '-m', model_dir, '-p', pack_number,
                '-sg', space_group]

        pack_number = str(pack_number)
        model_name = os.path.basename(os.path.normpath(model_dir))
        self.res_dir = '_'.join([model_name, pack_number, dashed_space_group])

        args.extend(['-r', self.res_dir])

        self._temp_dir = tempfile.mkdtemp()
        args.extend(['-po', os.path.join(self._temp_dir, "out_dir")])
        args.extend(['-ps', os.path.join(self._temp_dir, "scr_dir")])

        super().__init__(*args)

    def get_results(self):
        """
        Return the results from morda_solve.

        Parse the generated files, and return the scores calculated
        by the tool.

        Return
        ------
        dict
            Containing the following keys:
                * percent: int
                * q_factor: float

        """
        xml_file_path = os.path.join(self.res_dir, "morda_solve.xml")
        result_tree = ElementTree.parse(xml_file_path).getroot()

        # Check error
        error_code = int(result_tree.find('./err_level').text)
        if error_code != 0:
            if error_code != 7:  # No solution
                error_message = result_tree.find('./message')
                raise RuntimeError(error_message.text)
            else:
                results = {
                    'q_factor': 0.0,
                    'percent': 0.0,
                    'Z_score': 0.0,
                    'r_init': 0.0,
                    'rf_init': 0.0,
                    'r_fin': 0.0,
                    'rf_fin': 0.0
                }
                return results

        results = {}
        results['q_factor'] = float(result_tree.find('./q_factor').text)
        results['percent'] = float(result_tree.find('./percent').text)
        results['Z_score'] = float(result_tree.find('./Z_score').text)
        results['r_init'] = float(result_tree.find('./r_init').text)
        results['rf_init'] = float(result_tree.find('./rf_init').text)
        results['r_fin'] = float(result_tree.find('./r_fin').text)
        results['rf_fin'] = float(result_tree.find('./rf_fin').text)

        return results

    def cleanup(self):
        """Remove temporary directory."""
        shutil.rmtree(self._temp_dir)


class MtzDmp():
    """
    Wrapper for mtzdmp tool.

    This class only provides the space group as dumped by mtzdmp.

    Methods
    -------
    run
        Run the tool mtzdmp.

    get_space_group
        Return the space group of an MTZ file.

    Attributes
    ----------
    output: string
        The raw output of mtzdmp.

    """

    def __init__(self, file_path):
        self.file_path = file_path
        self.output = None

    def run(self):
        """Run mtzdmp on an MTZ file."""
        command_line = ['mtzdmp', self.file_path]

        try:
            popen = subprocess.Popen(command_line,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
        except FileNotFoundError:
            print(("Please make CCP4 available in your $PATH before using "
                   "ContaMiner."),
                  file=sys.stderr)
            raise RuntimeError("mtzdmp cannot be found.")

        stdout, stderr = popen.communicate()

        if popen.returncode != 0:
            print("Call to mtzdmp failed.",
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            print("Output: \n%s" % stdout.decode('UTF-8'),
                  file=sys.stderr)
            print("Error: \n%s" % stderr.decode('UTF-8'),
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            raise RuntimeError("Call to mtzdmp failed.")

        self.output = stdout.decode('UTF-8')

    def get_space_group(self):
        """
        Return the space group of the MTZ file.

        Return
        ------
        string
            The space group, space " " separated.

        """
        output_list = self.output.split('\n')
        regexp = r'\* Space group = \'([A-Z0-9 ]+)\''

        for line in output_list:
            match = re.search(regexp, line)
            if match:
                return match.group(1)

        raise RuntimeError("No space group found in mtzdmp output.")


class AltSgList():
    """
    Wrapper for alt_sg_list.

    Attributes
    ----------
    space_group: string
        The space " " separated space group for which we want the alternatives.

    Methods
    -------
    run
        Run alt_sg_list with the given arguments.

    get_alt_sg
        Return the alternative space groups.

    """

    def __init__(self, space_group):
        self.space_group = space_group
        self.output = None
        self._temp_dir = tempfile.mkdtemp()

    def run(self):
        """Run alt_sg_list."""
        # Cannot rely on $PATH, because CCP4 and MoRDa both provide a
        # binary named alt_sg_list
        try:
            morda_prog = os.environ['MRD_PROG']
        except KeyError:
            print("Please source morda_env_sh before using ContaMiner.",
                  file=sys.stderr)
            raise RuntimeError("MoRDa tools cannot be found.")

        binary_path = os.path.join(morda_prog, "alt_sg_list")
        command_line = [binary_path,
                        '-sg', self.space_group,
                        '-po', self._temp_dir,
                        '-ps', self._temp_dir]

        try:
            popen = subprocess.Popen(command_line,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
        except FileNotFoundError:
            print(("Please make CCP4 available in your $PATH before using "
                   "ContaMiner."),
                  file=sys.stderr)
            raise RuntimeError("alt_sg_list cannot be found.")

        stdout, stderr = popen.communicate()

        if popen.returncode != 0:
            print("Call to alt_sg_list failed.",
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            print("Output: \n%s" % stdout.decode('UTF-8'),
                  file=sys.stderr)
            print("Error: \n%s" % stderr.decode('UTF-8'),
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            raise RuntimeError("Call to alt_sg_list failed.")

        self.output = stdout.decode('UTF-8')

    def get_alt_space_groups(self):
        """
        Return the list of alternative space groups.

        Return
        ------
        list(string)
            The list of alternative space groups, space ' ' separated.

        """
        # Take everything after --> --> (should only contain results)
        output_list = self.output.split('\n')

        sg_regex = r' *[0-9]+ +\"([A-Z0-9 ]+)\"'
        space_groups_lines = [re.match(sg_regex, res_line)
                              for res_line in output_list]
        space_groups = [match.group(1)
                        for match in space_groups_lines
                        if match]
        return space_groups

    def cleanup(self):
        """Remove temporary directory."""
        shutil.rmtree(self._temp_dir)


class Cif2Mtz():
    """
    Smart wrapper for cif2mtz.

    Attributes
    ----------
    input_file: string
        The path to the input file to convert to MTZ.

    Methods
    -------
    run
        Run cif2mtz if input file is not yet MTZ.

    get_output_file
        Get the path to the output file.

    Warning
    -------
    MoRDa does not give the same results when used with a CIF file or with
    its corresponding converted MTZ file. Bug in MoRDa or in cif2mtz?
    Do not use the converted file to feed MoRDa, but the original CIF file
    instead.

    """

    def __init__(self, input_file):
        self.input_file = input_file
        self.output_file = None

    def run(self):
        """Run cif2mtz if input file is not yet MTZ."""
        filename, ext = os.path.splitext(self.input_file)

        # If input file is already MTZ, stop here.
        if ext.lower() == "mtz":
            self.output_file = self.input_file
            return

        self.output_file = filename + '.mtz'
        command_line = ['cif2mtz', 'HKLIN', self.input_file,
                        'HKLOUT', self.output_file]

        try:
            popen = subprocess.Popen(command_line,
                                     stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
            popen.stdin.close()
            popen.wait()
            stdout = popen.stdout.read()
            stderr = popen.stdout.read()
        except FileNotFoundError:
            print(("Please make CCP4 available in your $PATH before using "
                   "ConteMiner."),
                  file=sys.stderr)
            raise RuntimeError("cif2mtz cannot be found.")

        finally:
            popen.stdout.close()
            popen.stderr.close()

        if popen.returncode != 0:
            print("Call to mtzdmp failed.",
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            print("Output: \n%s" % stdout.decode('UTF-8'),
                  file=sys.stderr)
            print("Error: \n%s" % stderr.decode('UTF-8'),
                  file=sys.stderr)
            print("-" * 50,
                  file=sys.stderr)
            raise RuntimeError("Call to mtzdmp failed.")

    def get_output_file(self):
        """Return the path to the converted file."""
        return self.output_file
