class abccsrportal
{
  define app($merchantid = 0, $container,
             $migration_uri        = "db2://$ds_1_ip:50000/$db_name:currentSchema=MIGRATION;",
             $migration_user       = "db2inst1",
             $migration_password   = "db2inst1") {
    include $container

    $path = "/usr/adagio_csr"

    package { ABC_CSRPortal:
      ensure  => latest,
      require => Package[$container];
    }

    file { "$path/WEB-INF/classes/jndi.properties":
      owner   => "$container",
      group   => "$container",
      mode    => 0644,
      ensure  => present,
      content => template("abccsrportal/jndi.properties.erb"),
      notify  => Supervisor::Service[$container],
      require => Package[ABC_CSRPortal];
    }

    file { "$path/WEB-INF/web.xml":
      owner   => "$container",
      group   => "$container",
      mode    => 0644,
      ensure  => present,
      content => template("abccsrportal/web.xml.erb"),
      notify  => Supervisor::Service[$container],
      require => Package[ABC_CSRPortal];
    }

    file { "$path/WEB-INF/classes/conf/wasp-csr.conf":
      owner   => "$container",
      group   => "$container",
      mode    => 0644,
      ensure  => present,
      content => template("abccsrportal/wasp-csr.conf.erb"),
      notify  => Supervisor::Service[$container],
      require => Package[ABC_CSRPortal];
    }

    file { "$path/WEB-INF/classes/conf/wasp-csr-dtsx.conf":
      owner   => "$container",
      group   => "$container",
      mode    => 0644,
      ensure  => present,
      content => template("abccsrportal/wasp-csr-dtsx.conf.erb"),
      notify  => Supervisor::Service[$container],
      require => Package[ABC_CSRPortal];
    }

    file { "$path/WEB-INF/classes/abc/csrportal/MigrationDocument.py":
      owner   => "$container",
      group   => "$container",
      mode    => 0644,
      ensure  => present,
      content => template("abccsrportal/MigrationDocument.py.erb"),
      notify  => Supervisor::Service[$container],
      require => Package[ABC_CSRPortal];
    }

    file { "/usr/$container/velocity.log":
      owner   => "$container",
      group   => "$container",
      mode    => 0755,
      ensure  => present,
      require => Package[$container];
    }
  }

  define proxy($host = "127.0.0.1", $gateway, $statics = "/usr/adagio_csr") {
    file { $title:
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abccsrportal/csrportal.conf.erb"),
      notify  => Service[httpd],
      require => Package[httpd];
    }
  }

  #$plugin_dir = $architecture ? {
  #  "x86_64" => "/usr/lib64/nagios/plugins",
  #  "i386"   => "/usr/lib/nagios/plugins"
  #}
  #
  #@file { "$plugin_dir/check_abc":
  #  owner   => "root",
  #  group   => "root",
  #  mode    => 0755,
  #  ensure  => present,
  #  source  => "puppet:///modules/abccsrportal/check_abc",
  #  require => Package[nagios-nrpe],
  #  tag     => "nagios_checks";
  #}
  #
  #nagios::target::command { "check_abc":
  #  command => "$plugin_dir/check_abc -s localhost:8080";
  #}
}
