class rsnapshot
{
  case $operatingsystem {
    centos:  {
      package { rsnapshot:
        ensure  => installed,
        require => Class[yum];  # it comes from rpmforge
      }
    }
    default: {
      package { rsnapshot: ensure => installed }
    }
  }

  file { "/etc/rsnapshot.conf":
    owner   => "root",
    group   => "root",
    mode    => 0600,
    ensure  => present,
    source  => "puppet:///modules/rsnapshot/rsnapshot.conf",
    require => Package[rsnapshot];
  }

  file { "/snapshot":
    owner  => "root",
    group  => "root",
    mode   => 0700,
    type   => directory,
    ensure => directory;
  }

  case $operatingsystem {
    centos:  {
      file { "/etc/cron.daily/rsnapshot":
        content => "#!/bin/sh\n/usr/bin/rsnapshot -c /etc/rsnapshot.conf daily",
        owner   => "root",
        group   => "root",
        mode    => 0755,
        ensure  => present;
      }
      file { "/etc/cron.weekly/rsnapshot":
        content => "#!/bin/sh\n/usr/bin/rsnapshot -c /etc/rsnapshot.conf weekly",
        owner   => "root",
        group   => "root",
        mode    => 0755,
        ensure  => present;
      }
      file { "/etc/cron.monthly/rsnapshot":
        content => "#!/bin/sh\n/usr/bin/rsnapshot -c /etc/rsnapshot.conf monthly",
        owner   => "root",
        group   => "root",
        mode    => 0755,
        ensure  => present;
      }
    }
    default: {
      cron { "rsnapshot-daily":
        command => "",
        user    => "root",
        hour    => "23",
        minute  => "50",
        require => File["/etc/rsnapshot.conf"];
      }
      cron { "rsnapshot-weekly":
        command => "/usr/bin/rsnapshot -c /etc/rsnapshot.conf weekly",
        user    => "root",
        hour    => "23",
        minute  => "35",
        weekday => "saturday",
        require => File["/etc/rsnapshot.conf"];
      }
      cron { "rsnapshot-monthly":
        command  => "/usr/bin/rsnapshot -c /etc/rsnapshot.conf monthly",
        user     => "root",
        hour     => "23",
        minute   => "20",
        monthday => "1",
        require  => File["/etc/rsnapshot.conf"];
      }
    }
  }
}
