#!/bin/sh
set -e
set -x

# Install the system packages needed for building the PyInstaller based binary
apt-get update
apt-get install -y gcc python libssl-dev libffi-dev git
apt-get install -y python-pip python-dev

# Install python dependencies
pip install --upgrade pip
pip install -r https://raw.githubusercontent.com/projectcalico/libcalico/master/build-requirements-frozen.txt
pip install git+https://github.com/projectcalico/libcalico.git
pip install simplejson 
pip uninstall -y pyinstaller
git clone https://github.com/pyinstaller/pyinstaller.git
cd pyinstaller && cd bootloader && python2.7 ./waf distclean all --no-lsb 
cd .. &&  python2.7 setup.py install

# Produce a binary - outputs to /dist/controller
cd /
pyinstaller /code/controller.py -ayF

# Cleanup everything that was installed now that we have a self contained binary
#apk del temp && rm -rf /var/cache/apk/*
#rm -rf /usr/lib/python2.7
