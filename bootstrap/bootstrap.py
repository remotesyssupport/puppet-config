#!/usr/bin/env python

# jww (2011-07-04): Have remote git clone a puppet repo to start the server

# Ruby details

ruby_version     = "1.8.7"
ruby_rev         = "7"
ruby_date        = "2011.03"
rubygems_version = "1.5.2"
ruby_tarball     = 'ruby-enterprise-%s-%s.tar.gz' % (ruby_version, ruby_date)

##############################################################################
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
        'loglevel': False,
        'remote':   False
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
        usage = 'usage: %prog [options]'
        op = self.option_parser = optparse.OptionParser(usage = usage)

        op.add_option('-v', '--verbose',
                      action='store_true', dest='verbose',
                      default=False, help='show informational messages')
        op.add_option('-q', '--quiet',
                      action='store_true', dest='quiet',
                      default=False, help='do not show log messages on console')
        op.add_option('', '--log', metavar='FILE',
                      type='string', action='store', dest='logfile',
                      default=False, help='append logging data to FILE')
        op.add_option('', '--loglevel', metavar='LEVEL',
                      type='string', action='store', dest='loglevel',
                      default=False, help='set log level: DEBUG, INFO, WARNING, ERROR, CRITICAL')
        op.add_option('', '--remote',
                      action='store_true', dest='remote',
                      default=False, help='indicates script is running on the remote side')

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

app = None

def mkreader(*args, **kwargs):
    app.log.info(str(args))
    kwargs['stdout'] = subprocess.PIPE
    p = subprocess.Popen(args, **kwargs)
    return p.stdout

def mkwriter(*args, **kwargs):
    app.log.info(str(args))
    kwargs['stdin'] = subprocess.PIPE
    p = subprocess.Popen(args, **kwargs)
    return p.stdin

def shuttle(reader, writer):
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
    #if 'stdout' not in kwargs: kwargs['stdout'] = sys.stdout
    #if 'stderr' not in kwargs: kwargs['stderr'] = sys.stderr

    if 'cwd' in kwargs:
        cwd = os.getcwd()
        app.log.info('%s (in %s)' % (args, cwd))
        try:
            os.chdir(kwargs['cwd'])
            if subprocess.call(args, **kwargs) == 0:
                return True
            else:
                raise Exception("Command failed: %s (in %s)" % (args, cwd))
        finally:
            os.chdir(cwd)
    else:
        app.log.info(str(args))
        if subprocess.call(args, **kwargs) == 0:
            return True
        else:
            raise Exception("Command failed: " + str(args))

##############################################################################

class Machine(object):
    is_64bit = False
    packages = []
    gems     = []

    def __init__(self):
        self.packages = []
        self.gems     = []

    def install(self, *pkgs):
        raise Exception("Not implemented")

    def installed_packages(self):
        raise Exception("Not implemented")

    def remove(self, *pkgs):
        to_remove = []

        for pkg in pkgs:
            if self.has_package(pkg):
                to_remove.append(pkg)
                break

        if len(to_remove) > 0:
            self.uninstall_package(*to_remove)

    def uninstall_package(self, *pkgs):
        raise Exception("Not implemented")

    def cleanup_packages(self):
        pass

    def has_package(self, pkg):
        for package in self.installed_packages():
            if re.search(re.escape(pkg), package):
                return package
        return None

    def gem_install(self, *pkgs):
        for pkg in pkgs:
            if pkg not in self.gems:
                shell('gem', 'install', '-r', pkg)

    def installed_gems(self):
        if not self.gems:
            for line in mkreader('gem', 'list'):
                match = re.match('^(.+?) \(.+\)', line)
                if match:
                    self.gems.append(match.group(1))
        return self.gems

    def gem_remove(self, *pkgs):
        raise Exception("Not implemented")

class Machine_CentOS(Machine):
    def __init__(self):
        Machine.__init__(self)

        self.dist     = "el5"
        self.is_64bit = platform.architecture()[0] == '64bit'

        if self.is_64bit:
            self.arch = 'x86_64'
        else:
            self.arch = 'i386'

        self.ruby_rpm     = \
            join('/tmp/puppet/centos',
                 'ruby-enterprise-%s-%s.%s.%s.rpm' %
                 (ruby_version, ruby_rev, self.dist, self.arch))
        self.rubygems_rpm = \
            join('/tmp/puppet/centos',
                 'ruby-enterprise-rubygems-%s-%s.%s.%s.rpm' %
                 (rubygems_version, ruby_rev, self.dist, self.arch))

    def install(self, *pkgs):
        if self.is_64bit:
            shell('yum', 'install', '-y', *map(lambda x: x + '.x86_64', pkgs))
        else:
            shell('yum', 'install', '-y', *pkgs)

    def uninstall_package(self, *pkgs):
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
            pkgs = filter(lambda x: not re.search('(x86_64|noarch)', x),
                          self.installed_packages())
            if pkgs:
                self.uninstall_package(*pkgs)

        self.cleanup_unneeded_packages()

    def cleanup_unneeded_packages(self):
        self.uninstall_package( 'atk'
                              , 'authconfig'
                              , 'bitstream-vera-fonts'
                              , 'cairo'
                              , 'cups-libs'
                              , 'dhcpv6-client'
                              , 'ecryptfs-utils'
                              , 'fontconfig'
                              , 'freetype'
                              , 'gtk2'
                              , 'hdparm'
                              , 'hicolor-icon-theme'
                              , 'libX11'
                              , 'libXau'
                              , 'libXcursor'
                              , 'libXdmcp'
                              , 'libXext'
                              , 'libXfixes'
                              , 'libXft'
                              , 'libXi'
                              , 'libXinerama'
                              , 'libXrandr'
                              , 'libXrender'
                              , 'libhugetlbfs'
                              , 'libjpeg'
                              , 'libpng'
                              , 'libtiff'
                              , 'pango'
                              , 'setserial'
                              , 'trousers'
                              , 'udftools'
                              , 'xorg-x11-filesystem')
        
    def install_ruby(self):
        srcdir  = '/usr/src/redhat'
        specs   = join(srcdir, 'SPECS')
        sources = join(srcdir, 'SOURCES')
        rpms    = join(srcdir, 'RPMS', self.arch)

        if not isfile(self.ruby_rpm):
            rpm = join(rpms, self.ruby_rpm)
            if not isfile(rpm):
                if not isdir(specs):   os.makedirs(specs)
                if not isdir(sources): os.makedirs(sources)

                shutil.copy(ruby_tarball, sources)
                shutil.copy('ruby-enterprise.spec', specs)
                shell('rpmbuild', '-bb',
                      '--define', 'dist .' + self.dist,
                      'ruby-enterprise.spec', cwd=specs)

            if isfile(rpm):
                shutil.copy(rpm, ".")
                shutil.copy(join(rpms, self.rubygems_rpm), ".")

        if not isfile(self.ruby_rpm):
            raise Exception("Failed to build the Ruby RPM " + self.ruby_rpm)

        if not self.has_package('ruby-enterprise'):
            shell('rpm', '-Uvh', self.ruby_rpm, self.rubygems_rpm)

class Machine_OpenIndiana(Machine):
    def __init__(self):
        Machine.__init__(self)

##############################################################################

class PuppetCommon(object):
    machine = None

    def __init__(self, machine):
        self.machine = machine

    def cleanup_packages(self):
        self.machine.cleanup_packages()

    def install_ruby(self):
        self.machine.install_ruby()

    def install_puppet(self):
        self.machine.gem_install('puppet')

    def bootstrap(self):
        raise Exception("Not implemented")

class PuppetAgent(PuppetCommon):
    def __init__(self, machine, puppet_host=None):
        PuppetCommon.__init__(self, machine)
        self.puppet_host = puppet_host

    def install_puppet(self):
        PuppetCommon.install_puppet(self)

        if not grep('/etc/hosts', '\<puppet\>'):
            append_file('/etc/hosts', '%s   puppet' % self.puppet_host)

    def bootstrap(self):
        shell('puppet', 'apply', '--verbose', 'bootstrap-agent.pp')

class PuppetMaster(PuppetCommon):
    def __init__(self, machine):
        PuppetCommon.__init__(self, machine)

    def install_puppet(self):
        PuppetCommon.install_puppet(self)

        if not grep('/etc/hosts', '\<puppet\>'):
            append_file('/etc/hosts', '127.0.0.1   puppet')

    def bootstrap(self):
        shell('puppet', 'apply', '--verbose', 'bootstrap-master.pp')

#############################################################################

class PuppetBootstrap(CommandLineApp):
    def main(self, *args):
        if self.options.remote:
            if sys.platform == 'linux2':
                machine = Machine_CentOS()
            elif sys.platform == 'sunos5':
                machine = Machine_OpenIndiana()
            else:
                raise Exception("Unknown machine type")

            if len(args) == 1:
                master = args[0]
                host   = PuppetAgent(machine, master)
            else:
                master = None
                host   = PuppetMaster(machine)

            host.cleanup_packages()

            host.install_ruby()
            host.install_puppet()

            host.bootstrap()

            shell('service', 'puppet', 'stop')
            if not master:
                shell('service', 'puppetmaster', 'stop')
                shutil.rmtree('/var/lib/puppet/ssl')
                shell('service', 'puppetmaster', 'start')

            shell('puppetd', '--test')
            if not master:
                shell('puppetca', '--sign', '--all')
                shell('puppetd', '--test')
                shell('service', 'puppet', 'start')

                shell('rpm', '-Uvh',
                      'http://repo.webtatic.com/yum/centos/5/latest.rpm')
                shell('yum', 'install', '-y', '--enablerepo=webtatic', 'git')
                shell('git', 'clone', 'git://github.com/jwiegley/puppet-config',
                      '/etc/puppet/modules')
        else:
            host   = args[0]
            ostype = args[1]

            shell('ssh', host, 'yum', 'install', '-y', 'rsync')
            shell('rsync', '-av', '--include=/%s/' % ostype, '--exclude=/*/',
                  './', '%s:/tmp/puppet/' % host)
            shell('ssh', host, 'chmod', 'ugo+rX', '/tmp/puppet')

            if len(args) > 2:
                master = args[2]
            else:
                master = ''     # this means we are bootstrapping a master

            #shell('ssh', host, 'python',
            #      '/tmp/puppet/bootstrap.py', '--remote', master)

app = PuppetBootstrap()
app.run()

sys.exit(0)

### bootstrap.py ends here
