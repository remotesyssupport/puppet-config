# Installed for drupal6:
#
# drupal6        noarch  6.9-1.el5.rf        rpmforge
# aspell         x86_64  12:0.60.3-7.1       base
# aspell-en      x86_64  50:6.0-2.1          base
# curl           x86_64  7.15.5-2.1.el5_3.4  updates
# gmp            x86_64  4.1.4-10.el5        base
# libidn         x86_64  0.6.5-1.1           base
# mysql          x86_64  5.0.58-jason.2      utterramblings
# perl-DBI       x86_64  1.52-2.el5          base
# php            x86_64  5.2.6-jason.1       utterramblings
# php-cli        x86_64  5.2.6-jason.1       utterramblings
# php-common     x86_64  5.2.6-jason.1       utterramblings
# php-gd         x86_64  5.2.6-jason.1       utterramblings
# php-mbstring   x86_64  5.2.6-jason.1       utterramblings
# php-mysql      x86_64  5.2.6-jason.1       utterramblings
# php-pdo        x86_64  5.2.6-jason.1       utterramblings

class drupal
{
  include postgres
  include apache::secure

  $packages = [ drupal6, php-pgsql ]

  package { $packages:
    ensure => installed,
    notify => Service[httpd];
  }

  postgres::database { "drupal":
    user     => "drupal",
    password => "drupal",
    notify   => Exec["initialize drupal database"];
  }

  exec { "initialize drupal database":
    user        => "postgres",
    # jww (2009-05-02): explicit version number in path!
    command     => "/bin/cat /usr/share/doc/rsyslog-pgsql-2.0.7/createDB.sql | /usr/bin/tail -n +3 | /bin/sed 's/Syslog/syslog/g' | /usr/bin/psql -U syslog",
    refreshonly => true,
    require     => Package[rsyslog-pgsql];
  }
}
