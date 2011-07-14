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
package { "mysql": provider => gem }
#exec { "install mysql gem":
#  user    => root,
#  command => "/usr/bin/gem install --include-dependencies --no-rdoc --no-ri mysql -- --with-mysql-config=/usr/bin/mysql_config",
#  unless  => "/usr/bin/gem list | /bin/grep -q ^mysql";
#}

service { mysqld:
  ensure     => running,
  enable     => true,
  hasstatus  => true,
  hasrestart => true;
}

define mysql_database($user, $passwd, $host = "localhost") {
  exec { "create MySQL user $user":
    user        => root,
    command     => "/usr/bin/mysql -u root -e \"CREATE USER $user@$host IDENTIFIED BY '$passwd';\"",
    unless      => "/usr/bin/mysql -u root mysql -e \"SELECT user FROM user WHERE user='$user'\" | /bin/grep -q $user",
    require     => Service[mysqld];
  }

  exec { "create MySQL database $title":
    user        => root,
    command     => "/usr/bin/mysql -u root -e 'CREATE DATABASE $title'",
    unless      => "/usr/bin/mysql -u root -e 'SHOW DATABASES' | /bin/grep -q $title",
    require     => Exec["create MySQL user $user"];
  }

  exec { "grant MySQL user $user":
    user        => root,
    command     => "/usr/bin/mysql -u root -e \"GRANT ALL PRIVILEGES ON $title.* TO $user@$host IDENTIFIED BY '$passwd'\"",
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
  hasrestart => true;
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

    # Building the mysql gem requires mysql-devel
    Package["mysql"] {
      require => [ Package["mysql-devel.$architecture"], Package["gcc"] ]
    }

    Service[puppetmaster] {
      require => [ Package["puppet"], Service[mysqld],
                   File["/etc/init.d/puppetmaster"] ]
    }

    Service[mysqld] {
      require => Package["mysql-server"]
    }
  }
  default: {
    Service[puppetmaster] {
      require => [ Package["puppet"], Service[mysqld] ]
    }
  }
}
