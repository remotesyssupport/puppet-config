class psacct
{
  package { psacct: ensure => latest }

  service { psacct:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[psacct];
  }
}
