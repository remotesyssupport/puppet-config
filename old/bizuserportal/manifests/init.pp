class bizuserportal
{
  include imagemagick
  include tomcat

  package { unzip: ensure  => latest }

  #package { BIZ_UserPortal:
  #  ensure  => latest,
  #  require => [ Package[unzip], Package[tomcat] ];
  #}

  #db2::license { "/usr/tomcat/webapps/bizcard.com/WEB-INF/lib":
  #  owner   => "tomcat",
  #  group   => "tomcat",
  #  require => Package[BIZ_UserPortal];
  #}

  #file { "/usr/tomcat/webapps/user/WEB-INF/classes/jndi.properties":
  #  content => template("bizuserportal/jndi.properties.erb"),
  #  notify  => Supervisor::Service[tomcat],
  #  require => Package[BIZ_UserPortal];
  #}

  $plugin_dir = $architecture ? {
    "x86_64" => "/usr/lib64/nagios/plugins",
    "i386"   => "/usr/lib/nagios/plugins"
  }

  @file { "$plugin_dir/check_biz":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/bizuserportal/check_biz",
    require => Package[nagios-nrpe],
    tag     => "nagios_checks";
  }

  nagios::target::command { "check_biz":
    command => "$plugin_dir/check_biz -s www.bizcard.com";
  }
}
