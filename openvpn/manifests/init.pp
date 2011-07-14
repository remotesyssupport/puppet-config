class openvpn
{
  package { openvpn: ensure => installed }

  file { "/etc/init.d/openvpn":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/openvpn/openvpn.init",
    require => Package[openvpn];
  }

  file { "/etc/openvpn":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => directory,
    type    => directory,
    recurse => true,
    source  => "puppet:///modules/openvpn/openvpn",
    notify  => Service[openvpn],
    require => Package[openvpn];
  }

  firewall::pre { openvpn: }
  firewall::rule { openvpn: }

  service { openvpn:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[openvpn];
  }

  selinux::policy { openvpn: }
}

class openvpn::bridge inherits openvpn
{
  package { bridge-utils: ensure => installed }

  file { "/etc/init.d/bridge":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/openvpn/bridge.init",
    notify  => Exec["install bridge service"],
    require => Package[bridge-utils];
  }

  exec { "install bridge service":
    user        => "root",
    command     => "/sbin/chkconfig --add bridge",
    refreshonly => true,
    require     => File["/etc/init.d/bridge"];
  }

  service { bridge:
    #ensure     => running,
    enable     => true,
    hasstatus  => false,
    hasrestart => true,
    require    => Exec["install bridge service"];
  }

  Service[openvpn] {
    require => Service[bridge]
  }
}
