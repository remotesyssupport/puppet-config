class rsyslog
{
  package { rsyslog: ensure => latest }

  service { syslog:
    ensure     => stopped,
    enable     => false,
    hasstatus  => true,
    hasrestart => true;
  }

  service { rsyslog:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => [ Package[rsyslog], Service[syslog] ];
  }

  nagios::target::service { rsyslog: }

  #file { "/var/run/log":
  #  owner  => "root",
  #  group  => "root",
  #  mode   => 0755,
  #  type   => directory,
  #  ensure => directory;
  #}
  #
  #file { "/usr/bin/syslog.pl":
  #  owner  => "root",
  #  group  => "root",
  #  mode   => 0755,
  #  ensure => present,
  #  source => "puppet:///modules/rsyslog/syslog.pl";
  #}
  #
  #define fifo($ident, $owner, $group, $facility = "local7", $priority = "info",
  #            $replicate = "false") {
  #  include rsyslog
  #
  #  exec { "create $title fifo":
  #    user    => "root",
  #    command => "/bin/mknod $title p && /bin/chown $owner.$group $title",
  #    creates => "$title",
  #    notify  => Exec["spawn $title fifo listener"],
  #    require => File["/var/run/log"];
  #  }
  #
  #  exec { "spawn $title fifo listener":
  #    command     => "/usr/bin/perl /usr/bin/syslog.pl $title $ident $facility $priority $replicate",
  #    refreshonly => true,
  #    require     => [ File["/usr/bin/syslog.pl"],
  #                     Exec["create $title fifo"] ];
  #  }      
  #}

  define client()
  {
    file { "/etc/rsyslog.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("rsyslog/rsyslog.conf.client.erb"),
      notify  => Service[rsyslog],
      require => Package[rsyslog];
    }

    file { "/etc/sysconfig/rsyslog":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      source  => "puppet:///modules/rsyslog/rsyslog.client",
      notify  => Service[rsyslog],
      require => Package[rsyslog];
    }
  }

  define server()
  {
    include postgres

    package { rsyslog-pgsql:
      ensure  => latest,
      require => Package[postgresql-server];
    }

    postgres::database { "syslog":
      user     => "syslog",
      password => "syslog",
      notify   => Exec["initialize syslog database"];
    }

    # jww (2009-05-02): explicit path reference here
    exec { "initialize syslog database":
      user        => "postgres",
      command     => "/bin/cat /usr/share/doc/rsyslog-pgsql-2.0.7/createDB.sql | /usr/bin/tail -n +3 | /bin/sed 's/Syslog/syslog/g' | /usr/bin/psql -U syslog",
      refreshonly => true,
      require     => Package[rsyslog-pgsql];
    }

    file { "/etc/rsyslog.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("rsyslog/rsyslog.conf.server.erb"),
      notify  => Service[rsyslog],
      require => Package[rsyslog];
    }

    file { "/etc/sysconfig/rsyslog":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      source => "puppet:///modules/rsyslog/rsyslog.server",
      notify  => Service[rsyslog],
      require => Package[rsyslog];
    }

    firewall::rule { rsyslog: }
  }
}
