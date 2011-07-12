class ntp
{
  package { ntp: ensure => installed }

  exec { "ntp-update":
    command     => "/usr/sbin/ntpdate -u clock.isc.org",
    timeout     => 120,
    subscribe   => Package[ntp],
    refreshonly => true;
  }

  service { ntpd:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[ntp];
  }

  nagios::target::service { ntpd: }

  #nagios::service { check_ntp_time:
  #  command => "check_nrpe",
  #  args    => "check_ntp_time";
  #}
}
