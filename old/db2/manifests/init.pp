class db2
{
  exec { "yum obsoletes checking conflicts":
    user    => "root",
    command => "/usr/bin/perl -i -pe 's/obsoletes=1/obsoletes=0/;' /etc/yum.conf",
    unless  => "/bin/grep -q '^obsoletes=0' /etc/yum.conf",
    before  => Package[db2];
  }

  package { db2: ensure => installed }

  service { db2:
    ensure     => running,
    enable     => true,
    hasstatus  => false,
    hasrestart => true,
    require    => Package[db2];
  }

  firewall::rule { db2: }

  user { "db2inst1":
    ensure   => present,
    #password => "db2inst1",
    groups   => [ "db2grp1", "dasadm1" ],
    home     => "/usr/db2/db2inst1",
    require  => Package[db2];
  }

  $plugin_dir = $architecture ? {
    "x86_64" => "/usr/lib64/nagios/plugins",
    "i386"   => "/usr/lib/nagios/plugins"
  }

  @file { "$plugin_dir/check_db2":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/db2/check_db2",
    require => Package[nagios-nrpe],
    tag     => "nagios_checks";
  }

  file { "/usr/db2/db2_export.sh":
    owner   => "db2inst1",
    group   => "db2grp1",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/db2/db2_export.sh",
    require => Package[db2];
  }

  file { "/usr/db2/db2_full.pl":
    owner   => "db2inst1",
    group   => "db2grp1",
    mode    => 0755,
    ensure  => present,
    content => template("db2/db2_full.pl.erb"),
    require => Package[db2];
  }

  file { "/usr/db2/db2_offline.pl":
    owner   => "db2inst1",
    group   => "db2grp1",
    mode    => 0755,
    ensure  => present,
    content => template("db2/db2_offline.pl.erb"),
    require => Package[db2];
  }

  file { "/usr/db2/db2dump":
    owner   => "db2inst1",
    group   => "db2grp1",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/db2/db2dump",
    require => Package[db2];
  }

  file { "/mnt/data/db2":
    owner   => "nobody",
    group   => "nobody",
    mode    => 0755,
    ensure  => directory,
    type    => directory;
  }

  file { "/mnt/data/db2/logs":
    owner   => "nobody",
    group   => "nobody",
    mode    => 0755,
    ensure  => directory,
    type    => directory,
    require => File["/mnt/data/db2"];
  }

  file { "/mnt/data/db2/backups":
    owner   => "nobody",
    group   => "nobody",
    mode    => 0755,
    ensure  => directory,
    type    => directory,
    require => File["/mnt/data/db2"];
  }

  cron { "db2_full":
    ensure  => present,
    command => "/usr/bin/perl /usr/db2/db2_full.pl > /dev/null",
    user    => "db2inst1",
    hour    => 3,
    minute  => 0,
    require => [ File["/usr/db2/db2_full.pl"],
                 File["/mnt/data/db2/logs"],
                 File["/mnt/data/db2/backups"] ];
  }

  #cron { "db2_offline":
  #  ensure  => present,
  #  command => "/usr/bin/perl /usr/db2/db2_offline.pl > /dev/null",
  #  user    => "db2inst1",
  #  hour    => 1,
  #  minute  => 0,
  #  weekday => 0,
  #  require => [ File["/usr/db2/db2_offline.pl"],
  #               File["/mnt/data/db2/logs"],
  #               File["/mnt/data/db2/backups"] ];
  #}

  define database($warn_apps = 20, $crit_apps = 50) {
    include db2

    cron { "db2_export_$title":
      ensure  => present,
      command => "/bin/sh /usr/db2/db2_export.sh $title /mnt/data/db2/backups",
      user    => "db2inst1",
      weekday => 0,
      hour    => 7,
      minute  => 0;
    }

    nagios::target::command { "db2_${name}_apps":
      command => "$plugin_dir/check_db2 -d $name -t apps -w $warn_apps -c $crit_apps";
    }
    nagios::target::command { "db2_${name}_locks":
      command => "$plugin_dir/check_db2 -d $name -t locks -w 2 -c 5";
    }
    nagios::target::command { "db2_${name}_space1":
      command => "$plugin_dir/check_db2 -d $name -t space -w 30 -c 10 -i 1";
    }
    nagios::target::command { "db2_${name}_space2":
      command => "$plugin_dir/check_db2 -d $name -t space -w 30 -c 10 -i 2";
    }
    nagios::target::command { "db2_${name}_space3":
      command => "$plugin_dir/check_db2 -d $name -t space -w 30 -c 10 -i 3";
    }
    nagios::target::command { "db2_${name}_health":
      command => "$plugin_dir/check_db2 -d $name -t health";
    }
  }

  define license($owner, $group) {
    file { "$title/db2java.zip":
      owner  => "$owner",
      group  => "$group",
      mode   => 0644,
      ensure => present,
      source => "puppet:///modules/db2/db2java.zip";
    }

    file { "$title/db2jcc.jar":
      owner  => "$owner",
      group  => "$group",
      mode   => 0644,
      ensure => present,
      source => "puppet:///modules/db2/db2jcc.jar";
    }

    file { "$title/db2jcc_license_cu.jar":
      owner  => "$owner",
      group  => "$group",
      mode   => 0644,
      ensure => present,
      source => "puppet:///modules/db2/db2jcc_license_cu.jar";
    }
  }
}
