class tomcat
{
  include java

  package { tomcat: ensure => installed }

  user { tomcat:
    groups  => [ "tomcat", "nobody" ],
    home    => "/usr/tomcat",
    ensure  => present,
    require => Package[tomcat];
  }

  file { "/usr/tomcat/logs":
    owner   => "tomcat",
    group   => "tomcat",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => User[tomcat];
  }

  file { "/usr/tomcat/work":
    owner   => "tomcat",
    group   => "tomcat",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => Package[tomcat];
  }

  file { "/usr/tomcat/temp":
    owner   => "tomcat",
    group   => "tomcat",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => Package[tomcat];
  }

  file { "/usr/tomcat/webapps":
    owner   => "tomcat",
    group   => "tomcat",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => Package[tomcat];
  }

  firewall::rule { tomcat: }

  define server($options = "", $min_memory = "128m", $max_memory = "512m") {
    include supervisor

    file { "/etc/supervisord.d/tomcat.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      content => template("tomcat/tomcat.ini.erb"),
      notify  => Service[supervisor],
      require => Package[tomcat];
    }

    supervisor::service { tomcat:
      ensure  => running,
      enable  => true;
    }
  }

  define manager($password) {
    file { "/usr/tomcat/conf/tomcat-users.xml":
      owner   => "root",
      group   => "tomcat",
      mode    => 0640,
      content => template("tomcat/tomcat-users.xml.erb"),
      require => Package[tomcat];
    }
  }
}
