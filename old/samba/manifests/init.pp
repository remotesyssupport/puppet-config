class samba
{
  package { samba: ensure => latest }
}

class samba::server
{
  include samba

  file { "/etc/samba/smb.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/samba/smb.conf";
  }

  service { smb:
    ensure     => running,
    enable     => true,
    hasstatus  => false,
    hasrestart => true,
    require    => Package[samba];
  }

  firewall::rule { samba: }

  tcpwrapper { smbd: allow => "ALL" }
}
