class splunk
{
  package { splunk: ensure => latest }

  exec { "create splunk init file":
    user    => "root",
    command => "/opt/splunk/bin/splunk enable boot-start",
    creates => "/etc/init.d/splunk",
    require => Package[splunk];
  }

  exec { "initial splunk startup":
    user        => "root",
    command     => "/opt/splunk/bin/splunk start --accept-license",
    refreshonly => true,
    subscribe   => Package[splunk],
    before      => Exec["create splunk init file"],
    require     => Package[splunk];
  }

  service { splunk:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Exec["create splunk init file"];
  }

  nagios::target::service { splunk: }

  firewall::rule { splunk: }
}
