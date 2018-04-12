"""Test the config module."""

import os
import tempfile
import shutil
import unittest

import contaminer
from contaminer import config


class ConfigTest(unittest.TestCase):
    """Test the user_config class."""

    def setUp(self):
        """Change $HOME directory to tmp directory."""
        self.home_dir = tempfile.mkdtemp()
        self.home_dir_orig = os.environ['HOME']
        os.environ['HOME'] = self.home_dir

    def tearDown(self):
        """Remove test $HOME directory."""
        shutil.rmtree(self.home_dir)
        os.environ['HOME'] = self.home_dir_orig

    def test_create_config(self):
        """Test if a default config file is created."""
        conf = config.UserConfig().load()
        self.assertTrue(os.path.isfile(
            os.path.join(self.home_dir, ".contaminer", "config.ini")))
        self.assertIn('PATH', conf.sections())

    def test_load_existing_config(self):
        """Test if a given config path is properly loaded."""
        config_path = os.path.join(
            os.path.dirname(contaminer.__file__),
            'test_config',
            'config1.ini')
        conf = config.UserConfig(config_path).load()
        self.assertDictEqual(dict(conf['PATH']),
                             {'ccp4': '/opt/ccp4', 'morda': '/opt/morda'})
