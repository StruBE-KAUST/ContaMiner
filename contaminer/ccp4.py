"""Provide wrappers for CCP4 tools and MoRDa."""

import subprocess


class Morda():
    """Wrapper to execute MoRDa."""

    def __init__(self, tool, *args):
        """Store tool and args."""
        if tool in ["solve", "prep"]:
            self.tool = tool
        else:
            raise ValueError("tool can be \"solve\" or \"prep\".")

        self.tool = tool
        self.args = args

    def run(self):
        """Build command line and launch MoRDa with the args from init."""
        # Build command line
        command_line = self.parse_args()

        # Run MoRDa
        popen = subprocess.Popen(command_line, stdout=subprocess.PIPE)
        popen.wait()
        output = popen.stdout.read()
        return output

    def parse_args(self):
        """Build command line according to config and given args."""
        command_line = ['morda_' + self.tool]
        command_line.extend(self.args)

        return command_line


class MordaPrep(Morda):
    """Wrapper to execute MoRDa prep."""

    def __init__(self, fasta, nb_homologous=1):
        """Build underlying wrapper according to arguments."""
        super().__init__("prep", "-s", fasta, "-n", nb_homologous)


class MordaSolve(Morda):
    """Wrapper to execute MoRDa solve."""

    def __init__(self, mtz_file, model_dir, pack_number, space_group,
                 res_dir=None, out_dir=None, scr_dir=None):
        """Build underlying wrapper according to arguments."""
        args = ["solve", '-f', mtz_file, '-m', model_dir, '-p', pack_number,
                '-sg', space_group]

        if res_dir:
            args.extend(['-r', res_dir])

        if out_dir:
            args.extend(['-po', out_dir])

        if scr_dir:
            args.extend(['-ps', scr_dir])

        super().__init__(*args)
