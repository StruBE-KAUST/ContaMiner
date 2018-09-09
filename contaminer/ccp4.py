"""Provide wrappers for CCP4 tools and MoRDa."""

import os
import shutil
import subprocess
import sys
import tempfile


CONTABASE_DIR = os.environ['CONTABASE_DIR']


# pylint: disable=too-few-public-methods
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
        self.args = args
        self.output = None

    def run(self):
        """Build command line and launch MoRDa with the args from init."""
        # Build command line
        command_line = self._build_command()

        # Run MoRDa
        try:
            popen = subprocess.Popen(command_line,
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
        except FileNotFoundError:
            print("Please source morda_env_sh before using ContaMiner.",
                  file=sys.stderr)
            raise RuntimeError("MoRDa tools cannot be found.")

        popen.wait()
        if popen.returncode != 0:
            print("Call to %s failed." % 'morda_' + self.tool,
                  file=sys.stderr)
            print('-' * 50,
                  file=sys.stderr)
            print("Output: \n%s" % popen.stdout.read().decode('UTF-8'),
                  file=sys.stderr)
            print('-' * 50,
                  file=sys.stderr)
            print("Error: %s" % popen.stderr.read().decode('UTF-8'),
                  file=sys.stderr)
            print('-' * 50,
                  file=sys.stderr)
            raise RuntimeError("Call to morda_%s failed." % self.tool)

        self.output = popen.stdout.read()

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

    def __init__(self, fasta, nb_homologous=1):
        args = ["-s", fasta]
        args.extend(["-n", str(nb_homologous)])
        args.append('--alt')

        fasta_name = os.path.basename(os.path.splitext(fasta)[0])
        models_dir = os.path.join(CONTABASE_DIR, fasta_name)
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

    def __init__(self, mtz_file, model_dir, pack_number, space_group,
                 res_dir=None, out_dir=None, scr_dir=None):
        args = ["solve", '-f', mtz_file, '-m', model_dir, '-p', pack_number,
                '-sg', space_group]

        if res_dir:
            args.extend(['-r', res_dir])
        if out_dir:
            args.extend(['-po', out_dir])
        if scr_dir:
            args.extend(['-ps', scr_dir])

        (_, self._temp_dir) = tempfile.mkstemp()

        super().__init__(*args)

    def cleanup(self):
        """Remove temporary directory."""
        shutil.rmtree(self._temp_dir)
