
##############################################################################
##############################################################################
##############################################################################

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
