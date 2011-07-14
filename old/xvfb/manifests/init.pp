class xvfb
{
  $packages = [ xorg-x11-xauth, xorg-x11-server-Xvfb,
                xorg-x11-utils, xorg-x11-xfs ]

  package { $packages: ensure => installed }

  service { xfs:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[xorg-x11-xfs];
  }

  nagios::target::service { xfs: }
}
