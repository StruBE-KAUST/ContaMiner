"""Test contaminer.args_manager."""

import os
import tempfile
import unittest

from contaminer import args_manager

TEST_DIR = os.path.dirname(os.path.realpath(__file__))


class ArgumentsListManagerTest(unittest.TestCase):
    """Test ArgumentsListManager."""

    def setUp(self):
        """Modify the ContaBase path to something in test dir."""
        args_manager.CONTABASE_DIR = ""

    def test_create(self):
        """Create proper arguments list."""
        os.chdir(os.path.join(TEST_DIR, "data"))
        manager = args_manager.ArgumentsListManager()
        manager.create('5jk4-sf.cif', ['B4SL31'])

        args_list = manager._args_list

        self.assertEqual(len(args_list), 10)
        self.assertIn(
            {
                'model_dir': 'B4SL31/models',
                'pack_number': 5,
                'input_file': '5jk4-sf.cif',
                'space_group': 'P 1 2 1'
            },
            args_list)

    def test_save_and_load(self):
        """Saving and loading data should bring the same content."""
        os.chdir(os.path.join(TEST_DIR, "data"))

        # Save a list of args.
        saver = args_manager.ArgumentsListManager()
        saver.create('5jk4-sf.cif', ['B4SL31'])
        temp_save_file = tempfile.mktemp()

        try:
            saver.save(temp_save_file)

            # Load saved args.
            loader = args_manager.ArgumentsListManager()
            loader.load(temp_save_file)

            # Args should be the same
            self.assertEqual(saver._args_list, loader._args_list)
        finally:
            os.remove(temp_save_file)


if __name__ == "__main__":
    unittest.main()
