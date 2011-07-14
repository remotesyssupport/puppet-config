class nfs::client
{
  package { nfs-utils: ensure => installed }

  service { portmap:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[nfs-utils];
  }

  nagios::target::service { portmap: }

  service { rpcidmapd:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[nfs-utils];
  }

  nagios::target::service { rpcidmapd: }

  service { nfslock:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Service[portmap];
  }

  nagios::target::service { nfslock: }

  service { nfs:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Service[nfslock];
  }

  nagios::target::service { nfs: }

  define setup($nobody_user = "nobody", $nobody_group = "nobody") {
    include nfs::client

    file { "/etc/idmapd.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("nfs/idmapd.conf.erb"),
      notify  => [ Service[rpcidmapd], Service[nfs] ],
      require => Package[nfs-utils];
    }
  }

  define mount($host, $share) {
    include nfs::client

    file { "$name":
      type   => directory,
      ensure => directory,
      mode   => 0755;
    }

    mount { "$name":
      ensure  => mounted,
      device  => "$host:$share",
      atboot  => true,
      fstype  => "nfs",
      options => "rw,nosuid",
      require => [ File["$name"], Service[nfs] ];
    }
  }
}

define share_dirs($share_root)
{
  file { "${share_root}/$name":
    type   => directory,
    ensure => directory,
    owner  => "nobody",
    group  => "nobody",
    mode   => 0755;
  }
}

class nfs::server inherits nfs::client
{
  firewall::rule { nfs3: module => "nfs" }

  define exports($shares, $share_access, $share_options = "rw,sync",
                 $domain_name = "localdomain",
                 $nobody_user = "nobody", $nobody_group = "nobody") {
    include nfs::server

    share_dirs { $shares: share_root => $name }

    file { "/etc/sysconfig/nfs":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      source  => "puppet:///modules/nfs/nfs.sys",
      notify  => [ Service[rpcidmapd], Service[nfs] ],
      require => Package[nfs-utils];
    }

    file { "/etc/idmapd.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("nfs/idmapd.conf.erb"),
      notify  => [ Service[rpcidmapd], Service[nfs] ],
      require => Package[nfs-utils];
    }

    file { "/etc/exports":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      content => template("nfs/exports.erb"),
      notify  => Service[nfs],
      require => Package[nfs-utils];
    }
  }
}
