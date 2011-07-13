#!/usr/bin/env python

# jww (2011-07-04): Have a local bootstrap script to run the process from here
# jww (2011-07-04): Have remote git clone a puppet repo to start the server

##############################################################################

# This script is run in one of two ways:
#
#   puppet slave:  python bootstrap.py <IP ADDR OF 'puppet' MASTER>
#   puppet master: python bootstrap.py --server
#
# After running with --server, do the following final steps manually:
#
#  1. 'kill' puppetd and puppetmasterd (don't use 'service')
#  2. rm -fr /var/lib/puppet/ssl
#  3. service puppetmaster start
#  4. puppetd --test (this will fail due to lack of certificate)
#  5. puppetca --sign --all
#  6. puppetd --test
#  7. service puppet start (if the last step succeeded)
#
# After running to bootstrap a slave:
#
#  1. 'kill' puppetd (don't use 'service')
#  2. puppetd --test (this will fail due to lack of certificate)
#  3. (on the puppet master) puppetca --sign --all
#  4. puppetd --test
#  5. service puppet start (if the last step succeeded)
#
# This script is designed to be _idempotent_, meaning it can be run multiple
# times and only new changes will be added to the system.
#
##############################################################################

import inspect
import logging
import logging.handlers
import optparse
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import time

from os.path import *

##############################################################################

LEVELS = {'DEBUG':    logging.DEBUG,
          'INFO':     logging.INFO,
          'WARNING':  logging.WARNING,
          'ERROR':    logging.ERROR,
          'CRITICAL': logging.CRITICAL}

class CommandLineApp(object):
    "Base class for building command line applications."

    force_exit  = True           # If true, always ends run() with sys.exit()
    log_handler = None

    options = {
        'verbose':  False,
        'logfile':  False,
        'loglevel': False
        'master':   False,
    }

    def __init__(self):
        "Initialize CommandLineApp."
        # Create the logger
        self.log = logging.getLogger(os.path.basename(sys.argv[0]))
        ch = logging.StreamHandler()
        formatter = logging.Formatter("%(name)s: %(levelname)s: %(message)s")
        ch.setFormatter(formatter)
        self.log.addHandler(ch)
        self.log_handler = ch

        # Setup the options parser
        usage = 'usage: %prog [options] <BOUND-IP-ADDRESS>'
        op = self.option_parser = optparse.OptionParser(usage = usage)

        op.add_option('-v', '--verbose',
                      action='store_true', dest='verbose',
                      default=False, help='show informational messages')
        op.add_option('-q', '--quiet',
                      action='store_true', dest='quiet',
                      default=False, help='do not show log messages on console')
        op.add_option('-s', '--master',
                      action='store_true', dest='master',
                      default=False, help='bootstrap a puppet master')
        op.add_option('', '--log', metavar='FILE',
                      type='string', action='store', dest='logfile',
                      default=False, help='append logging data to FILE')
        op.add_option('', '--loglevel', metavar='LEVEL',
                      type='string', action='store', dest='loglevel',
                      default=False, help='set log level: DEBUG, INFO, WARNING, ERROR, CRITICAL')

    def main(self, *args):
        """Main body of your application.

        This is the main portion of the app, and is run after all of the
        arguments are processed.  Override this method to implment the primary
        processing section of your application."""
        pass

    def handleInterrupt(self):
        """Called when the program is interrupted via Control-C or SIGINT.
        Returns exit code."""
        self.log.error('Canceled by user.')
        return 1

    def handleMainException(self):
        "Invoked when there is an error in the main() method."
        if not self.options.verbose:
            self.log.exception('Caught exception')
        return 1

    ## INTERNALS (Subclasses should not need to override these methods)

    def run(self):
        """Entry point.

        Process options and execute callback functions as needed.  This method
        should not need to be overridden, if the main() method is defined."""
        # Process the options supported and given
        self.options, main_args = self.option_parser.parse_args()

        if self.options.logfile:
            fh = logging.handlers.RotatingFileHandler(self.options.logfile,
                                                      maxBytes = (1024 * 1024),
                                                      backupCount = 5)
            formatter = logging.Formatter("%(asctime)s - %(levelname)s: %(message)s")
            fh.setFormatter(formatter)
            self.log.addHandler(fh)

        if self.options.quiet:
            self.log.removeHandler(self.log_handler)
            ch = logging.handlers.SysLogHandler()
            formatter = logging.Formatter("%(name)s: %(levelname)s: %(message)s")
            ch.setFormatter(formatter)
            self.log.addHandler(ch)
            self.log_handler = ch

        if self.options.loglevel:
            self.log.setLevel(LEVELS[self.options.loglevel])
        elif self.options.verbose:
            self.log.setLevel(logging.DEBUG)
        else:
            self.log.setLevel(logging.INFO)
        
        exit_code = 0
        try:
            # We could just call main() and catch a TypeError, but that would
            # not let us differentiate between application errors and a case
            # where the user has not passed us enough arguments.  So, we check
            # the argument count ourself.
            argspec = inspect.getargspec(self.main)
            expected_arg_count = len(argspec[0]) - 1

            if len(main_args) >= expected_arg_count:
                exit_code = self.main(*main_args)
            else:
                self.log.debug('Incorrect argument count (expected %d, got %d)' %
                               (expected_arg_count, len(main_args)))
                self.option_parser.print_help()
                exit_code = 1

        except KeyboardInterrupt:
            exit_code = self.handleInterrupt()

        except SystemExit, msg:
            exit_code = msg.args[0]

        except Exception:
            exit_code = self.handleMainException()
            if self.options.verbose:
                raise
            
        if self.force_exit:
            sys.exit(exit_code)
        return exit_code

def mkreader(self, *args, **kwargs):
    self.log.info(str(args))
    kwargs['stdout'] = subprocess.PIPE
    p = subprocess.Popen(args, **kwargs)
    return p.stdout

def mkwriter(self, *args, **kwargs):
    self.log.info(str(args))
    kwargs['stdin'] = subprocess.PIPE
    p = subprocess.Popen(args, **kwargs)
    return p.stdin

def shuttle(self, reader, writer):
    data = reader.read(8192)
    while data:
        writer.write(data)
        data = reader.read(8192)

def grep(path, regexp):
    fd = open(path, 'r')
    for line in fd:
        if re.search(regexp, line):
            return True
    fd.close()
    return False

def append_file(path, line_to_add):
    temp_path = join('/tmp', basename(path))

    fd = open(path, 'r')
    out = open(temp_path, 'w')
    for line in fd:
        out.write(line)
    out.write(line_to_add)
    out.write('\n')
    out.close()
    fd.close()

    fd = open(temp_path, 'r')
    out = open(path, 'w')
    for line in fd:
        out.write(line)
    out.close()
    fd.close()

    os.remove(temp_path)

def shell(*args, **kwargs):
    if 'stdout' not in kwargs: kwargs['stdout'] = sys.stdout
    if 'stderr' not in kwargs: kwargs['stderr'] = sys.stderr

    if 'cwd' in kwargs:
        cwd = os.getcwd()
        print '%s (in %s)' % (args, cwd)
        try:
            os.chdir(kwargs['cwd'])
            if subprocess.call(args, **kwargs) == 0:
                return True
            else:
                raise Exception("Command failed: %s (in %s)" % (args, cwd))
        finally:
            os.chdir(cwd)
    else:
        print args
        if subprocess.call(args, **kwargs) == 0:
            return True
        else:
            raise Exception("Command failed: " + str(args))
    def shell(self, *args, **kwargs):

        self.log.info(str(args))
        if subprocess.call(args, **kwargs) == 0:
            return True
        else:
            raise Exception("Command failed: " + str(args))

##############################################################################

class Machine(object):
    is_64bit = False
    packages = []

    def __init__(self):
        self.packages = []

    def install(self, *pkgs):
        raise Exception("Not implemented")

    def uninstall(self, *pkgs):
        raise Exception("Not implemented")

    def remove(*pkgs):
        to_remove = []
        for pkg in pkgs:
            if has_package(pkg):
                to_remove.append(pkg)
                break
        if len(to_remove) > 0:
            self.uninstall(*to_remove)

    def installed_packages(self):
        raise Exception("Not implemented")

    def cleanup_packages(self):
        pass

    def has_package(self, pkg):
        for package in self.installed_packages():
            if re.search(re.escape(pkg), package):
                return package
        return None

class Machine_CentOS(Machine):
    def __init__(self):
        Machine.__init__(self)
        self.is_64bit = platform.architecture()[0] == '64bit'

    def install(self, *pkgs):
        if self.is_64bit:
            shell('yum', 'install', '-y', *map(lambda x: x + '.x86_64', pkgs))
        else:
            shell('yum', 'install', '-y', *pkgs)

    def uninstall(self, *pkgs):
        shell('yum', 'remove', '-q', '-y', *pkgs)

    def installed_packages(self):
        if not self.packages:
            for line in mkreader('yum', 'list', 'installed'):
                match = re.match('^(.+?)\s+', line)
                if match:
                    package = match.group(1)
                    if re.search('\.', package):
                        self.packages.append(package)
        return self.packages

    def cleanup_packages(self):
        # Clean up non-64bit packages
        if self.is_64bit:
            remove(*filter(lambda x: not re.search('(x86_64|noarch)', x),
                           self.installed_packages()))

##############################################################################

class PuppetCommon(object):
    machine = None

    def __init__(self, machine):
        self.machine = machine

class PuppetAgent(PuppetCommon):
    pass

class PuppetMaster(PuppetCommon):
    pass

#############################################################################

# Build and install Ruby

arch             = 'x86_64'
ruby_version     = "1.8.7"
ruby_rev         = "7"
ruby_date        = "2011.03"
rubygems_version = "1.5.2"
dist             = "el5"

ruby_tarball     = 'ruby-enterprise-%s-%s.tar.gz' % (ruby_version, ruby_date)
ruby_rpm         = 'ruby-enterprise-%s-%s.%s.%s.rpm' % \
                   (ruby_version, ruby_rev, dist, arch)
rubygems_rpm     = 'ruby-enterprise-rubygems-%s-%s.%s.%s.rpm' % \
                   (rubygems_version, ruby_rev, dist, arch)

if sys.platform == 'linux2':
    srcdir  = '/usr/src/redhat'
    specs   = join(srcdir, 'SPECS')
    sources = join(srcdir, 'SOURCES')
    rpms    = join(srcdir, 'RPMS', arch)

    if not isfile(ruby_rpm):
        rpm = join(rpms, ruby_rpm)
        if not isfile(rpm):
            if not isdir(specs):   os.makedirs(specs)
            if not isdir(sources): os.makedirs(sources)

            # These are the packages needed to build RPMs in general, and the
            # Ruby Enterprise RPMs in particular
            install64('autoconf',
                      'automake',
                      'libtool',
                      'make',
                      'gcc',
                      'gcc-c++',
                      'glibc-devel',
                      'kernel-devel',
                      'rpm-build',
                      'rpm-devel',
                      'openssl-devel',
                      'readline-devel',
                      'zlib-devel')

            shutil.copy(ruby_tarball, sources)
            shutil.copy('ruby-enterprise.spec', specs)
            shell('rpmbuild', '-bb', '--define', 'dist .' + dist,
                  'ruby-enterprise.spec', cwd=specs)

        if isfile(rpm):
            shutil.copy(rpm, ".")
            shutil.copy(join(rpms, rubygems_rpm), ".")

    if not isfile(ruby_rpm):
        raise Exception("Failed to build the Ruby RPM " + ruby_rpm)

    if not has_package('ruby-enterprise'):
        shell('rpm', '-Uvh', ruby_rpm, rubygems_rpm)

# Install Puppet via Rubygems

gems = []
for line in mkreader('gem', 'list'):
    match = re.match('^(.+?) \(.+\)', line)
    if match:
        gems.append(match.group(1))

def gem_install(*pkgs):
    for pkg in pkgs:
        if pkg not in gems:
            shell('gem', 'install', '-r', pkg)

gem_install('puppet')

if not grep('/etc/hosts', '\<puppet\>'):
    if sys.argv[-1] != sys.argv[0] and \
       not sys.argv[-1].startswith('--'):
        append_file('/etc/hosts', '%s   puppet' % sys.argv[-1])
    else:
        append_file('/etc/hosts', '127.0.0.1   puppet')

if master:
    shell('puppet', 'apply', '--verbose', 'bootstrap-master.pp')
else:
    shell('puppet', 'apply', '--verbose', 'bootstrap-agent.pp')

sys.exit(0)
