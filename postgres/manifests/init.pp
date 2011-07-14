class postgres
{
  $packages = [ postgresql, postgresql-server,
                "postgresql-devel.$architecture" ]

  package { $packages: ensure => installed }

  exec { init-postgresql:
    user    => "root",
    timeout => 600,
    command => "/sbin/service postgresql start",
    creates => "/var/lib/pgsql/data/pg_hba.conf",
    require => Package[postgresql-server];
  }

  file { "/etc/sysconfig/pgsql/postgresql":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/postgres/postgresql.sys",
    notify  => Service[postgresql],
    require => Exec[init-postgresql];
  }

  file { "/var/lib/pgsql/data/postgresql.conf":
    owner   => "postgres",
    group   => "postgres",
    mode    => 0600,
    ensure  => present,
    source  => "puppet:///modules/postgres/postgresql.conf",
    notify  => Service[postgresql],
    require => Exec[init-postgresql];
  }

  firewall::rule { postgres: }

  service { postgresql:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[postgresql-server];
  }

  nagios::target::service { postgresql: }

  nagios::service { check_pgsql:
    args => "template1!postgres";
  }

  define access($database = "all", $user = "all", $method = "ident sameuser") {
    exec { "postgresql access for $title":
      user    => "postgres",
      command => "/bin/echo 'host $database $user $title $method' >> /var/lib/pgsql/data/pg_hba.conf",
      unless  => "/bin/grep -q '^host.*$title' /var/lib/pgsql/data/pg_hba.conf";
    }
  }

  define database($user, $password, $command = false) {
    exec { "create postgres user $user":
      user        => "postgres",
      command     => "/usr/bin/psql -c \"CREATE USER $user WITH UNENCRYPTED PASSWORD '$password'\" template1",
      unless      => "/usr/bin/psql -c \"SELECT usename FROM pg_user WHERE usename = '$user'\" template1 | /bin/grep -q '$user'",
      require     => Service[postgresql];
    }

    exec { "create postgres database $title":
      user        => "postgres",
      command     => $command ? {
        false   => "/usr/bin/createdb --encoding=UNICODE --owner=$user $title",
        default => $command
      },
      unless      => "/usr/bin/psql --list | /bin/grep -q '$title'",
      require     => Exec["create postgres user $user"];
    }

    exec { "grant postgres user $user":
      user        => "postgres",
      command     => "/usr/bin/psql -c \"GRANT ALL ON DATABASE $title TO $user\" template1",
      refreshonly => true,
      subscribe   => Exec["create postgres database $title"],
      require     => Exec["create postgres database $title"];
    }
  }
}
