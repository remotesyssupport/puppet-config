class abcuserportal
{
  include imagemagick
  include tomcat
  include mysql

  package { unzip: ensure  => latest }

  package { ABC_UserPortal:
    ensure  => latest,
    require => [ Package[unzip], Package[tomcat] ];
  }

  db2::license { "/usr/tomcat/webapps/user/WEB-INF/lib":
    owner   => "tomcat",
    group   => "tomcat",
    require => Package[ABC_UserPortal];
  }

  file { "/usr/tomcat/webapps/user/WEB-INF/classes/jndi.properties":
    content => template("abcuserportal/jndi.properties.erb"),
    notify  => Supervisor::Service[tomcat],
    require => Package[ABC_UserPortal];
  }

  define app($abc_site_uri         = "db2://$ds_1_ip:50000/$db_name:currentSchema=ABC_SITE;",
             $abc_site_user        = "db2inst1",
             $abc_site_password    = "db2inst1",
             $abc_catalog_uri      = "db2://$ds_1_ip:50000/$db_name:currentSchema=ABC_CATALOG;",
             $abc_catalog_user     = "db2inst1",
             $abc_catalog_password = "db2inst1",
             $migration_uri        = "db2://$ds_1_ip:50000/$db_name:currentSchema=MIGRATION;",
             $migration_user       = "db2inst1",
             $migration_password   = "db2inst1",
             $mysql_abc_uri        = "mysql://localhost/abc_userportal",
             $mysql_abc_user       = "abc_userportal",
             $mysql_abc_password   = "abc_userportal",
             $mysql_adc_uri        = "mysql://localhost/adc_userportal",
             $mysql_adc_user       = "adc_userportal",
             $mysql_adc_password   = "adc_userportal") {
    file { "/usr/tomcat/webapps/user/WEB-INF/classes/dispatches/admin/edit_region.hd":
      owner   => "tomcat",
      group   => "tomcat",
      mode    => 0600,
      content => template("abcuserportal/edit_region.hd.erb"),
      notify  => Supervisor::Service[tomcat],
      require => Package[ABC_UserPortal];
    }

    file { "/usr/tomcat/webapps/user/WEB-INF/classes/abc/userportal/MigrationDocument.py":
      owner   => "tomcat",
      group   => "tomcat",
      mode    => 0600,
      content => template("abcuserportal/MigrationDocument.py.erb"),
      notify  => Supervisor::Service[tomcat],
      require => Package[ABC_UserPortal];
    }

    file { "/usr/tomcat/webapps/user/WEB-INF/classes/abc/userportal/abc_ext.py":
      owner   => "tomcat",
      group   => "tomcat",
      mode    => 0600,
      content => template("abcuserportal/abc_ext.py.erb"),
      notify  => Supervisor::Service[tomcat],
      require => Package[ABC_UserPortal];
    }

    file { "/usr/tomcat/webapps/user/WEB-INF/classes/abc/userportal/editable_regions.py":
      owner   => "tomcat",
      group   => "tomcat",
      mode    => 0600,
      content => template("abcuserportal/editable_regions.py.erb"),
      notify  => Supervisor::Service[tomcat],
      require => Package[ABC_UserPortal];
    }
  }

  $plugin_dir = $architecture ? {
    "x86_64" => "/usr/lib64/nagios/plugins",
    "i386"   => "/usr/lib/nagios/plugins"
  }

  @file { "$plugin_dir/check_abc":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/abcuserportal/check_abc",
    require => Package[nagios-nrpe],
    tag     => "nagios_checks";
  }

  nagios::target::command { "check_abc":
    command => "$plugin_dir/check_abc -s localhost:8080";
  }
}
