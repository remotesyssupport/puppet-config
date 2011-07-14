class centos
{
  include yum

  package { epel-release: ensure => latest }

  file { "/etc/sysconfig/network": ensure => present }

  exec { "set-fqdn":
    command => "/usr/bin/perl -i -pe 's/HOSTNAME=.*/HOSTNAME=$fqdn/;' /etc/sysconfig/network",
    unless  => "/bin/grep -q ^HOSTNAME=$fqdn /etc/sysconfig/network";
  }

  group { adm: ensure => present }

  #exec { "disable root password":
  #  user        => "root",
  #  command     => "/usr/bin/passwd -l root"
  #  #, refreshonly => true
  #}

  exec { "set password for admin":
    user        => "root",
    command     => "/bin/echo admin | /usr/bin/passwd --stdin admin",
    refreshonly => true;
  }

  user { admin:
    groups  => [ "adm" ],
    home    => "/home/admin",
    ensure  => present,
    notify  => [ #Exec["disable root password"],
                 Exec["set password for admin"] ],
    require => Group[adm];
  }

  file { "/home/admin":
    owner   => "admin",
    group   => "adm",
    mode    => 0700,
    type    => directory,
    ensure  => directory,
    require => User[admin];
  }

  file { "/etc/yum.repos.d/CentOS-Base.repo":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/centos/CentOS-Base.repo",
    require => Package[yum];
  }

  file { "/etc/yum.repos.d/CentOS-Media.repo":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/centos/CentOS-Media.repo",
    require => Package[yum];
  }
}

class centos::admin
{
  include sudo

  $packages = [ man, man-pages, htop, tcpdump, socat, bind-utils, lsof,
                logrotate, logwatch, tmpwatch, p7zip, screen, tree,
                rsync, crontabs, vixie-cron, which, traceroute, nano ]

  package { $packages: ensure => latest }

  file { "/root/bin":
    owner  => "root",
    group  => "root",
    mode   => 0700,
    type   => directory,
    ensure => directory;
  }
}

class centos::devel
{
  $packages = [
                "autoconf",
                "automake",
                "bison",
                "bzip2-devel",
                "compat-libstdc++-33",
                "flex",
                "freetype-devel",
                "gcc",
                "gcc-c++",
                "giflib-devel",
                "glib2-devel",
                "glibc-devel",
                "gnutls-devel",
                "kernel-devel",
                "lcms-devel",
                "libaio",
                "libjpeg-devel",
                #"libnet-devel",
                "libpng-devel",
                "libtiff-devel",
                "libtool",
                "libxml2-devel",
                "make",
                "ncurses-devel",
                "openssl-devel",
                #"postgresql-devel",
                "python-devel",
                "readline-devel",
                "rpm-build",
                "rpm-devel",
                #"ruby-devel",
                #"zlib-devel"
              ]

  package { $packages: ensure => latest }
}
