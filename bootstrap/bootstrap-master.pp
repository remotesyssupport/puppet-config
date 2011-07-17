import '/tmp/puppet/bootstrap.pp'

file { "/etc/puppet/puppet.conf":
  owner   => root,
  group   => root,
  mode    => 0755,
  ensure  => present,
  source  => "/tmp/puppet/puppet-master.conf",
  require => Package["puppet"];
}

package { "rails": provider => gem }

service { mysqld:
  ensure     => running,
  enable     => true,
  hasstatus  => true,
  hasrestart => true;
}

define mysql_database($user, $passwd, $host = "localhost") {
  exec { "create MySQL user $user":
    user        => root,
    path        => "/usr/bin",
    command     => "sleep 30; mysql mysql -e \"CREATE USER $user@$host IDENTIFIED BY '$passwd';\"",
    unless      => "mysql mysql -e \"SELECT user FROM user WHERE user='$user'\" | grep -q $user",
    require     => Service[mysqld];
  }

  exec { "create MySQL database $title":
    user        => root,
    command     => "/usr/bin/mysql -e 'CREATE DATABASE $title'",
    unless      => "/usr/bin/mysql -e 'SHOW DATABASES' | grep -q $title",
    require     => Exec["create MySQL user $user"];
  }

  exec { "grant MySQL user $user":
    user        => root,
    command     => "/usr/bin/mysql -e \"GRANT ALL PRIVILEGES ON $title.* TO $user@$host IDENTIFIED BY '$passwd'\"",
    refreshonly => true,
    subscribe   => Exec["create MySQL database $title"],
    require     => Exec["create MySQL database $title"];
  }
}

#CREATE INDEX exported_restype_title ON resources(exported, restype, title(50));

mysql_database { "puppet":
  user     => "puppet",
  passwd   => "puppet";
}

service { puppetmaster:
  ensure     => running,
  enable     => true,
  hasstatus  => true,
  hasrestart => true,
  subscribe  => File["/etc/puppet/puppet.conf"];
}

case $operatingsystem {
  centos: {
    file { "/etc/init.d/puppetmaster":
      owner   => root,
      group   => root,
      mode    => 0755,
      ensure  => present,
      source => "/tmp/puppet/centos/puppetmaster.init";
    }

    $devel_pkgs = [ 'autoconf'
                  , 'automake'
                  , 'libtool'
                  , 'make'
                  , 'gcc'
                  , 'gcc-c++'
                  , 'glibc-devel'
                  , 'kernel-devel'
                  , 'rpm-build'
                  , 'rpm-devel'
                  , 'openssl-devel'
                  , 'readline-devel'
                  , 'zlib-devel'
                  ]

    package { $devel_pkgs: ensure => installed }

    $packages = [ "mysql-server", "mysql-devel.$architecture" ]

    package { $packages: ensure => installed }

    package { "mysql": provider => gem }

    # Building the mysql gem requires mysql-devel
    Package["mysql"] {
      require => [ Package["mysql-devel.$architecture"],
                   Package[$devel_pkgs] ]
    }

    Service[mysqld] {
      require => Package["mysql-server"]
    }

    Service[puppetmaster] {
      require => [ Package["puppet"], Service[mysqld],
                   File["/etc/init.d/puppetmaster"] ]
    }
  }

  Solaris: {
    group { puppet: ensure => present }

    file { "/etc/svc/profile/puppetmaster.xml":
      owner   => root,
      group   => root,
      mode    => 0755,
      ensure  => present,
      source  => "/tmp/puppet/solaris/puppetmaster.xml",
      require => Package[puppet];
    }

    exec { "install puppetmaster.xml manifest":
      user    => root,
      command => "/usr/sbin/svccfg import /etc/svc/profile/puppetmaster.xml",
      unless  => "/usr/sbin/svccfg list network/puppetmaster | grep -q network/puppetmaster",
      require => File["/etc/svc/profile/puppetmaster.xml"];
    }

    Service[puppetmaster] {
      name    => "network/puppetmaster",
      require => [ Package["puppet"], Service[mysqld],
                   Exec["install puppetmaster.xml manifest"] ]
    }

    $devel_pkgs = [ 'gcc-dev'
                  , 'library/math/header-math'
                  ]
    
    package { $devel_pkgs:
      provider => pkg,
      ensure   => installed;
    }
    
    $packages = [ "mysql-51", "mysql-51/library" ]
    
    package { $packages:
      provider => pkg,
      ensure   => installed;
    }

    ## Building the mysql gem requires mysql-devel
    #package { "mysql": provider => gem }
    #Package["mysql"] {
    #  require => [ Package["mysql-51/library"], Package[$devel_pkgs] ]
    #}

    exec { "manually install mysql gem":
      user    => root,
      command => "/usr/bin/gem install mysql -- --with-mysql-dir=/usr/mysql --with-mysql-lib=/usr/mysql/lib --with-mysql-include=/usr/mysql/include",
      unless  => "/usr/bin/gem list mysql | grep -q ^mysql",
      require => [ Package["mysql-51/library"], Package[$devel_pkgs] ];
    }

    Service[mysqld] {
      name    => "database/mysql",
      require => Exec["manually install mysql gem"]
    }
  }

  default: {
    Service[puppetmaster] {
      require => [ Package["puppet"], Service[mysqld] ]
    }
  }
}
