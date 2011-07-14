class jboss
{
  include java

  package { jboss: ensure => installed }

  firewall::rule { jboss: }

  define logger() {
    file { "/usr/jboss/server/default/conf/jboss-log4j.xml":
      owner   => "jboss",
      group   => "jboss",
      mode    => 0644,
      ensure  => present,
      content => template("jboss/jboss-log4j.xml.erb"),
      require => Package[jboss];
    }
  }

  file { "/usr/jboss/bin/native":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    recurse => true,
    source  => "puppet:///modules/jboss/native",
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default/conf/standardjbosscmp-jdbc.xml":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/jboss/standardjbosscmp-jdbc.xml",
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default/conf/standardjboss.xml":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/jboss/standardjboss.xml",
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default/deploy/ear-deployer.xml":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/jboss/ear-deployer.xml",
    require => Package[jboss];
  }

  file { "/usr/jboss/server/default/conf":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => File["/usr/jboss/server/default"];
  }
  file { "/usr/jboss/server/default/data":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => File["/usr/jboss/server/default"];
  }
  file { "/usr/jboss/server/default/deploy":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => File["/usr/jboss/server/default"];
  }
  file { "/usr/jboss/server/default/lib":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => File["/usr/jboss/server/default"];
  }
  file { "/usr/jboss/server/default/log":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => File["/usr/jboss/server/default"];
  }
  file { "/usr/jboss/server/default/work":
    owner   => "jboss",
    group   => "jboss",
    type    => directory,
    recurse => true,
    require => File["/usr/jboss/server/default"];
  }

  define server($serverid = 0, $min_memory = "128m", $max_memory = "768m",
                $options = "") {
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


  define datasource($url, $driver, $username, $password, $mapping) {
    file { "/usr/jboss/server/default/deploy/${title}.xml":
      owner   => "jboss",
      group   => "jboss",
      mode    => 0600,
      ensure  => present,
      content => template("jboss/datasource.xml.erb"),
      require => Package[jboss];
    }
  }
}
