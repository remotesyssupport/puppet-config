class abcadminportal
{
  include tomcat

  package { ABC_AdminPortal:
    ensure  => latest,
    require => Package[tomcat];
  }

  file { "/usr/tomcat/webapps/admin/WEB-INF/classes/jndi.properties":
    content => template("abcadminportal/jndi.properties.erb"),
    notify  => Supervisor::Service[tomcat],
    require => Package[ABC_AdminPortal];
  }

  file { "/usr/tomcat/webapps/admin/WEB-INF/web.xml":
    content => template("abcadminportal/web.xml.erb"),
    notify  => Supervisor::Service[tomcat],
    require => Package[ABC_AdminPortal];
  }

  file { "/usr/tomcat/webapps/admin/WEB-INF/classes/conf/wasp-admin.conf":
    content => template("abcadminportal/wasp-admin.conf.erb"),
    notify  => Supervisor::Service[tomcat],
    require => Package[ABC_AdminPortal];
  }

  define proxy() {
    file { $title:
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abcadminportal/adminportal.conf.erb"),
      notify  => Service[httpd],
      require => Package[httpd];
    }
  }

  db2::license { "/usr/tomcat/webapps/admin/WEB-INF/lib":
    owner   => "tomcat",
    group   => "tomcat",
    require => Package[ABC_AdminPortal];
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
  #  source  => "puppet:///modules/abcadminportal/check_abc",
  #  require => Package[nagios-nrpe],
  #  tag     => "nagios_checks";
  #}
  #
  #nagios::target::command { "check_abc":
  #  command => "$plugin_dir/check_abc -s localhost:8080";
  #}
}
