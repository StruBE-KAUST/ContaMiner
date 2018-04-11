#!/usr/bin/env python
"""
Setup tools installation.

Run this script to install or upgrade contaminer.
"""

import os
from setuptools import setup, find_packages

REQUIREMENTS = open(os.path.join(os.path.dirname(__file__),
                                 'requirements.txt')).readlines()
setup(name='contaminer',
      version='1.0.1',
      install_requires=REQUIREMENTS,
      packages=find_packages())
