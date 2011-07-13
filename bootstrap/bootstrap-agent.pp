package { "puppet": provider => gem }

file { "/etc/puppet/puppet.conf":
  owner   => root,
  group   => root,
  mode    => 0755,
  ensure  => present,
  source  => "/tmp/puppet/puppet-agent.conf",
  require => Package["puppet"];
}

group { puppet:
  ensure  => present,
  require => Package[puppet];
}

user { puppet:
  groups   => [ puppet ],
  home     => "/",
  shell    => "/usr/bin/false",
  ensure   => present,
  #password => '*',
  require  => Group[puppet];
}

service { puppet:
  ensure     => running,
  enable     => true,
  hasstatus  => true,
  hasrestart => true;
}

case $operatingsystem {
  centos: {
    file { "/etc/init.d/puppet":
      owner   => root,
      group   => root,
      mode    => 0755,
      ensure  => present,
      source  => "/tmp/puppet/puppet.init",
      require => Package[puppet];
    }

    Service[puppet] {
      require => [ Package[puppet], File["/etc/init.d/puppet"] ]
    }
  }
  default: {
    Service[puppet] {
      require => Package[puppet]
    }
  }
}
