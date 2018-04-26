#!/usr/bin/env python

from distutils.core import setup

setup(name='collectd-trident',
      version='1.0',
      description='A collectd plugin that reads trident measurements',
      author='CERN',
      author_email='david.smith@cern.ch',
      url='https://gitlab.cern.ch/UP/Trident',
      data_files=[('share/collectd',['share/trident_types.db'])],
      packages=['collectd_trident'])
