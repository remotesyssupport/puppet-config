class yum
{
  Yumrepo {
    notify => Exec["/usr/bin/yum makecache"]
  }

  exec { "/usr/bin/yum makecache":
    user        => "root",
    timeout     => 600,
    refreshonly => true;
  }

  yumrepo { base:       priority => 2, enabled => 1 }
  yumrepo { updates:    priority => 2, enabled => 1 }
  yumrepo { addons:     priority => 2, enabled => 1 }
  yumrepo { extras:     priority => 2, enabled => 1 }
  yumrepo { centosplus: priority => 2, enabled => 1 }

  #yumrepo { epel-puppet:
  #  descr      => "CentOS EPEL (puppet)",
  #  baseurl    => 'http://tmz.fedorapeople.org/repo/puppet/epel/$releasever/$basearch/',
  #  enabled    => 1,
  #  gpgcheck   => 0,
  #  priority   => 1;
  #}

  yumrepo { epel-stable:
    descr      => "CentOS EPEL (stable)",
    #baseurl    => 'http://download.fedora.redhat.com/pub/epel/$releasever/$basearch',
    baseurl    => 'http://mirrors.usu.edu/epel/$releasever/$basearch',
    #mirrorlist => 'http://mirrors.fedoraproject.org/mirrorlist?repo=epel-$releasever&arch=$basearch',
    enabled    => 1,
    gpgcheck   => 0,
    priority   => 2;
  }

  yumrepo { epel-testing:
    descr      => "CentOS EPEL (testing)",
    #baseurl    => 'http://download.fedora.redhat.com/pub/epel/testing/$releasever/$basearch',
    baseurl    => 'http://mirrors.usu.edu/epel/testing/$releasever/$basearch',
    #mirrorlist => 'http://mirrors.fedoraproject.org/mirrorlist?repo=testing-epel-$releasever&arch=$basearch',
    enabled    => 1,
    gpgcheck   => 0,
    priority   => 2;
  }

  yumrepo { rpmforge:
    descr      => 'Red Hat Enterprise $releasever - RPMforge.net - dag',
    gpgkey     => "http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt",
    mirrorlist => 'http://apt.sw.be/redhat/el$releasever/en/mirrors-rpmforge',
    enabled    => 1,
    protect    => 0,
    gpgcheck   => 1,
    priority   => 3;
  }

  yumrepo { utterramblings:
    descr    => "Jason's Utter Ramblings Repo",
    baseurl  => 'http://www.jasonlitka.com/media/EL$releasever/$basearch/',
    enabled  => 1,
    gpgcheck => 1,
    gpgkey   => "http://www.jasonlitka.com/media/RPM-GPG-KEY-jlitka",
    priority => 3;
  }

  yumrepo { "pgdg-84-centos":
    descr    => 'PostgreSQL 8.4 $releasever - $basearch',
    baseurl  => 'http://yum.pgsqlrpms.org/8.4/redhat/rhel-$releasever-$basearch',
    enabled  => 1,
    gpgcheck => 0,
    gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-PGDG',
    priority => 1;
  }

  Package {
    require => [ Yumrepo[base],
                 Yumrepo[updates],
                 Yumrepo[addons],
                 Yumrepo[extras],
                 Yumrepo[centosplus],
                 #Yumrepo[epel-puppet],
                 Yumrepo[epel-stable],
                 Yumrepo[epel-testing],
                 Yumrepo[rpmforge],
                 Yumrepo[utterramblings],
                 Yumrepo["pgdg-84-centos"] ]
  }

  $packages = [ yum, yum-priorities, yum-protectbase, yum-utils,
                rpmforge-release ]

  package { $packages: ensure => latest }
}

class yum::repository inherits yum
{
  include vsftpd

  package { createrepo: ensure => latest }

  file { "$vsftpd::ftpd_directory/yum":
    owner   => "ftp",
    group   => "ftp",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "public_content_t",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => File["$vsftpd::ftpd_directory"];
  }

  file { "$vsftpd::ftpd_directory/yum/rhel":
    owner   => "ftp",
    group   => "ftp",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "public_content_t",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => File["$vsftpd::ftpd_directory/yum"];
  }

  file { "$vsftpd::ftpd_directory/yum/rhel/5":
    owner   => "ftp",
    group   => "ftp",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "public_content_t",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => File["$vsftpd::ftpd_directory/yum/rhel"];
  }

  file { "$vsftpd::ftpd_directory/yum/rhel/5/i386":
    owner   => "ftp",
    group   => "ftp",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "public_content_t",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => File["$vsftpd::ftpd_directory/yum/rhel/5"];
  }

  file { "$vsftpd::ftpd_directory/yum/rhel/5/x86_64":
    owner   => "ftp",
    group   => "ftp",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "public_content_t",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => File["$vsftpd::ftpd_directory/yum/rhel/5"];
  }
}
