"""User entry point to ContaMiner. Parse args and call controller."""

import argparse


def main():
    """Main function, parsing args and calling the controller."""
    # Parse command
    parser = argparse.ArgumentParser()
    command_parser = parser.add_subparsers(dest='subcommand')

    # Init parser
    command_parser.add_parser('init')

    # Solve parser
    solve_parser = command_parser.add_parser('solve')
    solve_parser.add_argument(
        "input_file",
        type=str,
        help="MTZ of CIF file to analyze for contaminants.")

    args = parser.parse_args()

    # Init
    if args.subcommand == 'init':
        raise NotImplementedError

    # Solve
    if args.subcommand == 'solve':
        raise NotImplementedError


if __name__ == "__main__":
    main()
