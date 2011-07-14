package { "puppet": provider => gem }

user { puppet:
  home     => "/",
  shell    => "/usr/bin/false",
  ensure   => present;
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
      source  => "/tmp/puppet/centos/puppet.init",
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
