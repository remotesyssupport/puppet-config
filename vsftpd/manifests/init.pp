class vsftpd
{
  $ftpd_uses_xinetd = false

  if $ftpd_uses_xinetd {
    include xinetd
  }

  # Due to dependency cycles, this has to be installed before puppet is run on
  # the puppetmaster
  #package { vsftpd: ensure => latest }

  $allow_anonymous_ftp = "YES"    # change to YES if desired
  $allow_local_ftp     = "NO"
  $ftpd_write_enable   = "NO"
  $ftpd_banner         = "Welcome to this FTP service."
  $ftpd_directory      = "/srv/ftp"
  $ftpd_pasv_min_port  = 50000
  $ftpd_pasv_max_port  = 60000

  if $ftpd_uses_xinetd {
    file { "/etc/xinetd.d/vsftpd":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      source  => "puppet:///modules/vsftpd/vsftpd.xinetd",
      require => Package[xinetd];
    }
  }

  file { "/etc/vsftpd/vsftpd.conf":
    owner   => "root",
    group   => "root",
    mode    => 600,
    ensure  => present,
    content => template("vsftpd/vsftpd.conf.erb"),
    notify  => Service[vsftpd];
  }

  group { "ftp":  ensure => present }

  user { "ftp":
    ensure  => present,
    groups  => [ "ftp" ],
    home    => "$ftpd_directory";
  }

  file { $ftpd_directory:
    owner   => "ftp",
    group   => "ftp",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "public_content_t",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => [ User[ftp], Group[ftp] ];
  }

  tcpwrapper { vsftpd: allow => "ALL" }

  service { vsftpd:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => [ File["/etc/vsftpd/vsftpd.conf"],
                    File["$ftpd_directory"] ];
  }

  nagios::target::service { vsftpd: }

  nagios::service { check_ftp: }

  file { "/etc/firewall.d/ftp.ipt":
    owner   => "root",
    group   => "root",
    mode    => 0600,
    ensure  => present,
    content => template("vsftpd/ftp.ipt.erb"),
    notify  => Exec[reset-firewall];
  }

  selinux::policy { vsftpd-ext: module => "vsftpd" }
}
