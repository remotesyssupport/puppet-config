class dnsmasq
{
  package { dnsmasq: ensure => latest }

  firewall::rule { dns: module => "dnsmasq" }

  file { "/etc/dnsmasq.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    content => template("dnsmasq/dnsmasq.conf.erb"),
    notify  => Service[dnsmasq],
    require => Package[dnsmasq];
  }

  service { dnsmasq:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[dnsmasq];
  }

  nagios::target::service { dnsmasq: }

  nagios::service { check_dig:
    args => "$gw_1";
  }

  tcpwrapper { dns: allow => "ALL" }
}
