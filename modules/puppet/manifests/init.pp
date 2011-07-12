class puppet::client
{
  include firewall
  include ruby

  yumrepo { puppet:
    descr    => "Puppet managed packages",
    baseurl  => 'ftp://puppet/yum/rhel/$releasever/$basearch/',
    enabled  => 1,
    gpgcheck => 0,
    priority => 1;
  }
  
  Package {
    require => Yumrepo[puppet]
  }

  #$packages = [ puppet, facter ]
  #
  #package { $packages: ensure => latest }

  ruby::rubygem { puppet: }

  $node_environment = "production"

  file { "/etc/init.d/puppet":
    owner   => root,
    group   => root,
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/puppet/puppet.init",
    require => Ruby::Rubygem[puppet];
  }

  file { "/etc/puppet/puppet.conf":
    owner   => root,
    group   => root,
    mode    => 0644,
    ensure  => present,
    content => template("puppet/puppet.conf.erb"),
    #notify => Service[puppet],
    require => Ruby::Rubygem[puppet];
  }

  firewall::rule { puppet: }

  service { puppet:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    pattern    => puppetd,
    require    => [ Ruby::Rubygem[puppet],
                    File["/etc/init.d/puppet"],
                    File["/etc/puppet/puppet.conf"] ];
  }

  nagios::target::service { puppet: }
}

class puppet::server inherits puppet::client
{
  include vsftpd
  include yum::repository
  include centos::devel

  Yumrepo[puppet] { require => Service[vsftpd] }

  firewall::rule { puppetmaster: module => "puppet" }

  #package { puppet-server:
  #  ensure  => latest,
  #  require => [ Package[puppet], Yumrepo[puppet] ];
  #}

  file { "/etc/init.d/puppetmaster":
    owner   => root,
    group   => root,
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/puppet/puppetmaster.init",
    require => Ruby::Rubygem[puppet];
  }

  service { puppetmaster:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    pattern    => puppetmasterd,
    require    => [ File["/etc/init.d/puppetmaster"],
                    File["/etc/puppet/puppet.conf"],
                    Service[vsftpd] ];
  }

  nagios::target::service { puppetmaster: }
}

class puppet::server::stored_configs inherits puppet::server
{
  include postgres
  include ruby::rails

  ruby::rubygem { postgres:
    require => [ Class[postgres], Ruby::Rubygem[rails] ];
  }

  postgres::database { "puppet":
    user     => "puppet",
    password => "puppet";
  }

  File["/etc/puppet/puppet.conf"] {
    content => template("puppet/puppet.conf.stored_config.erb"),
    require => [ Postgres::Database["puppet"],
                 Ruby::Rubygem[postgres] ]
  }
}
