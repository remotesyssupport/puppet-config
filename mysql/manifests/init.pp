class mysql
{
  $packages = [ mysql, mysql-server, "mysql-devel.$architecture" ]

  package { $packages: ensure => installed }

  # CREATE DATABASE abc_userportal;
  # CREATE USER 'abc_userportal'@'localhost' IDENTIFIED BY PASSWORD('abc_userportal');
  # GRANT ALL PRIVILEGES ON abc_userportal.* TO 'abc_userportal'@'localhost' WITH GRANT OPTION;

  #exec { init-postgresql:
  #  user    => "root",
  #  timeout => 600,
  #  command => "/sbin/service postgresql start",
  #  creates => "/var/lib/pgsql/data/pg_hba.conf",
  #  require => Package[postgresql-server];
  #}

  #file { "/etc/sysconfig/pgsql/postgresql":
  #  owner   => "root",
  #  group   => "root",
  #  mode    => 0644,
  #  ensure  => present,
  #  source  => "puppet:///modules/postgres/postgresql.sys",
  #  notify  => Service[postgresql],
  #  require => Exec[init-postgresql];
  #}

  #file { "/var/lib/pgsql/data/postgresql.conf":
  #  owner   => "postgres",
  #  group   => "postgres",
  #  mode    => 0600,
  #  ensure  => present,
  #  source  => "puppet:///modules/postgres/postgresql.conf",
  #  notify  => Service[postgresql],
  #  require => Exec[init-postgresql];
  #}

  firewall::rule { mysql: }

  service { mysqld:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[mysql-server];
  }

  nagios::target::service { mysqld: }

  #nagios::service { check_mysql:
  #  args => "mysql!mysql";
  #}
}
