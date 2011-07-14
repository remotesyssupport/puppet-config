class bittorrent::tracker
{
  include supervisor

  $packages = [ python-twisted-core, python-twisted-web, python-crypto ]

  package { $packages: ensure => latest }

  file { "/srv/bittorrent":
    owner  => "ftp",
    group  => "ftp",
    mode   => 0755,
    type   => directory,
    ensure => directory;
  }

  firewall::rule { bittorrent-tracker: module => "bittorrent" }

  file { "/etc/supervisord.d/bittorrent-tracker.ini":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    content => template("bittorrent/bittorrent-tracker.ini.erb");
  }

  supervisor::service { bittorrent-tracker:
    ensure  => running,
    enable  => true,
    require => File["/srv/bittorrent"];
  }
}
