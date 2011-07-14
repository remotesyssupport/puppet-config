class wine
{
  $packages = [ wine, samba-client, "freetype.i386", cabextract ]

  package { $packages: ensure => installed }

  service { winbind:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[samba-client];
  }

  nagios::target::service { winbind: }
}
