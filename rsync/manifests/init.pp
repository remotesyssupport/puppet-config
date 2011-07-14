class rsync
{
  include vsftpd
  include xinetd

  package { rsync: ensure => installed }

  file { "/etc/xinetd.d/rsync":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/rsync/rsync.xinetd",
    require => Package[xinetd];
  }

  file { "/etc/rsyncd.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => template("rsync/rsync.conf.erb"),
    require => Package[rsync];
  }

  tcpwrapper { rsync: }
}
