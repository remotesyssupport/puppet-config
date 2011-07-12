class sshd
{
  case $operatingsystem {
    centos: {
      include centos
      $ssh_packages = ["openssh", "openssh-server", "openssh-clients"]
    }
    fedora: { $ssh_packages = ["openssh", "openssh-server", "openssh-clients"] }
    default: { $ssh_packages = ["openssh", "openssh-server", "openssh-clients"] } 
  }

  package { $ssh_packages: ensure => installed }

  firewall::rule_tmpl { sshd: }

  file { "/root/.ssh":
    owner   => "root",
    group   => "root",
    mode    => 0700,
    type    => directory,
    ensure  => directory,
    require => User[admin];
  }

  file { "/root/.ssh/authorized_keys":
    owner   => "root",
    group   => "root",
    mode    => 0600,
    ensure  => present,
    source  => "puppet:///modules/sshd/authorized_keys",
    require => File["/root/.ssh"];
  }

  file { "/home/admin/.ssh":
    owner   => "admin",
    group   => "adm",
    mode    => 0700,
    type    => directory,
    ensure  => directory,
    require => User[admin];
  }

  file { "/home/admin/.ssh/authorized_keys":
    owner   => "admin",
    group   => "adm",
    mode    => 0600,
    ensure  => present,
    source  => "puppet:///modules/sshd/authorized_keys",
    require => File["/home/admin/.ssh"];
  }

  file { "/etc/ssh/sshd_config":
    owner   => "root",
    group   => "root",
    mode    => 0600,
    ensure  => present,
    source  => "puppet:///modules/sshd/sshd_config",
    notify  => Service[sshd],
    require => Package[openssh-server];
  }

  service { sshd:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[openssh-server];
  }

  nagios::target::service { sshd: }

  nagios::service { check_ssh: }

  tcpwrapper { sshd: allow => "ALL" }
}
