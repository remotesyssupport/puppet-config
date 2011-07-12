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
##############################################################################

import re
import os
import sys
import shutil
import platform
import subprocess

from os.path import *

server = False
if '--server' in sys.argv:
    server = True

# This script is designed to be _idempotent_, meaning it can be run multiple
# times and only new changes will be added to the system.

def mkreader(*args, **kwargs):
    print args
    kwargs['stdout'] = subprocess.PIPE
    p = subprocess.Popen(args, **kwargs)
    return p.stdout

def mkwriter(*args, **kwargs):
    print args
    kwargs['stdin'] = subprocess.PIPE
    p = subprocess.Popen(args, **kwargs)
    return p.stdin

def shell(*args, **kwargs):
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

def install(*pkgs):
    shell('yum', 'install', '-y', *pkgs)

def install64(*pkgs):
    shell('yum', 'install', '-y', *map(lambda x: x + '.x86_64', pkgs))

packages = []

def get_package_list():
    global packages
    if sys.platform == 'linux2':
        for line in mkreader('yum', 'list', 'installed'):
            match = re.match('^(.+?)\s+', line)
            if match:
                package = match.group(1)
                if re.search('\.', package):
                    packages.append(package)

def has_package(pkg):
    global packages
    if not packages: get_package_list()
    for package in packages:
        if re.search(re.escape(pkg), package):
            return package

    return None

def remove(*pkgs):
    to_remove = []
    for pkg in pkgs:
        if has_package(pkg):
            to_remove.append(pkg)
            break
    if len(to_remove) > 0:
        shell('yum', 'remove', '-q', '-y', *to_remove)

# Clean up non-64bit packages

if sys.platform == 'linux2' and platform.architecture()[0] == '64bit':
    if not packages:
        get_package_list()
    remove(*filter(lambda x: not re.search('(x86_64|noarch)', x), packages))

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

if server:
    shell('puppet', 'apply', '--verbose', 'bootstrap-master.pp')
else:
    shell('puppet', 'apply', '--verbose', 'bootstrap.pp')

sys.exit(0)

##############################################################################
##############################################################################
##############################################################################

def shuttle(reader, writer):
    data = reader.read(8192)
    while data:
        writer.write(data)
        data = reader.read(8192)

def modify(path, regexp, subst=None):
    modified  = False
    temp_path = join('/tmp', basename(path))

    fd = open(path, 'r')
    out = open(temp_path, 'w')
    for line in fd:
        if subst:
            new_line = re.sub(regexp, subst, line)
            if line != new_line:
                modified = True
                line = new_line
        elif re.search(regexp, line):
            modified = True
            continue
        out.write(line)
    out.close()
    fd.close()

    fd = open(temp_path, 'r')
    out = open(path, 'w')
    for line in fd:
        out.write(line)
    out.close()
    fd.close()

    os.remove(temp_path)

    return modified

##############################################################################

# Setup SSH

if not isdir('/root/.ssh'):
    os.mkdir('/root/.ssh', 0700)

if not isdir('/root/.ssh/authorized_keys'):
    authorized_keys = open('/root/.ssh/authorized_keys', 'w')
    authorized_keys.write('''ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAuieodZ1orcaND9D7eOurADUH353+3ngTgKRt+SZ9clstR4l4lWr4BCZrrEITS3lka6AgqNDepNfGIuGrFoQkV/3R2aathNNZJt/vsSCFSD2RbUNDiAl4JODqkVXpdUsDS+0DLtsvHfTlpgfTabU3rs/WJuG3YnpSFFRclYoE7aLeuKgI+0HtrtIQVyzO+E6+t3eAVKlgRi6c0f0MKeElHsgh5s1InxPUMr8JiT9C+3Uio2DlTUT0wZc0Amix0JbpgfsxJ8uSqn/0z93ty133ZJX6KzvB95aF6AFnseptzM5/Fl5CKclbsOta99NBEGVjZwpzUZNhXRfaEtAWQI/Htw==
mobile@John-Wiegleys-iPhone
ssh-dss AAAAB3NzaC1kc3MAAACBAIW3kMaGkdT02c09kslw+/HPOVPpuquwySb2vXgrdvtJsrUtJiEsyP+Us5s0T3ZzlDfqKHs5CdPXGe28/TzPgzCqL/sRcJid9Tddu1a2bt9Sfy9iEdNEt+jb0llBqLAcjRHT3tSR/PqcT3Pf3/gk2rFge1nC0x/41OL6rHyUk4IDAAAAFQCVFfTWFTobd10lkMRBncDecpktxQAAAIBfhRw/VwYGf93JcyOre3MKhoezPS0DbH0QqmQrs2KJgD+ZvimB9qc6dBLlOoy0HjjbCIiNsonwlgJ4EWeutWbabwqr3A3MH9fDuvhTdRqkUdyQsbQZkL0iU2UZ+jKnZNgOXYTFBJECHVlaX0wgaAk9sB3li+rFY91tsYI/mpwPrwAAAIA/HHj7nZ4O8pZsnsv6EeSWyoHVw1L0AfPKOa5dQuARNKDe4Ef96n+T3mdSBcuUdzVW1+co0y98as6z1DqNAS7pr2LILDMU9dn1YIE3SLqSoxzi1VxN7XWE7wwbr+64Wr/7M8d3AGFe3pYR8zHCeOD2YBaH05CCIdf4bWKUo6NcRw== johnw@aris
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEAwTFboeliU48xemZzecpkVylbQ+mCbBCf1WxwpIRVZCpv4Qqod+hzez7nJFeMfr1XVHdo2J0WyJAvbtinGxRBLa23DoyPtLppTy3YCZyiRJ8ULx6J1sBwhFwYZe4ZF2l0EBDzD4RsrQCtozQPmnv3QBHQ85zMi5PjXusLXoqmQjk= johnw@aris
''')
    os.chmod('/root/.ssh/authorized_keys', 0600)

if isfile('/etc/ssh/sshd_config'):
    if not modify('/etc/ssh/sshd_config',
                  '^#?PermitRootLogin .*', 'PermitRootLogin without-password'):
        append_file('/etc/ssh/sshd_config', 'PermitRootLogin without-password')

if sys.platform == 'sunos5':
    modify('/etc/default/login', '^CONSOLE=/dev/login', '#CONSOLE=/dev/login')
    shell('rolemod', '-K', 'type=normal', 'root')
    shell('svcadm', 'restart', 'ssh')

elif sys.platform == 'linux2':
    shell('service', 'sshd', 'restart')

##############################################################################

##############################################################################

modify('/etc/sysconfig/network', '^HOSTNAME=.*', 'HOSTNAME=puppet.local')

### bootstrap.py ends here
