class jboss
{
  include java

  package { jboss: ensure => installed }

  firewall::rule { jboss: }

  define logger() {
    file { "/usr/jboss/server/default/conf/jboss-log4j.xml":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("jboss/jboss-log4j.xml.erb"),
      require => Package[jboss];
    }
  }

  file { "/usr/jboss/server/default/conf/standardjbosscmp-jdbc.xml":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/jboss/standardjbosscmp-jdbc.xml",
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default/conf/jboss-server.xml":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/jboss/jboss-service.xml",
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default/log":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => Package[jboss];
  }
  file { "/usr/jboss/server/default/data":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => Package[jboss];
  }

  define server($serverid = 0, $max_memory = "768m", $options = "") {
    include supervisor

    file { "/etc/supervisord.d/jboss.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("jboss/jboss.ini.erb"),
      notify  => Service[supervisor];
    }

    supervisor::service { jboss:
      ensure  => running,
      enable  => true;
    }
  }
}
