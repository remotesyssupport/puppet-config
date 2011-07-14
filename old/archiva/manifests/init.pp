class archiva
{
  include jboss

  package { archiva: ensure => installed }

  file { "/usr/jboss/server/default/deploy/archiva-1.3.ear/apache-archiva.war/WEB-INF/classes/application.properties":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///archiva/application.properties";
  }

  file { "/usr/jboss/server/default/deploy/archiva-1.3.ear/apache-archiva.war/WEB-INF/jboss-web.xml":
    owner   => "jboss",
    group   => "jboss",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///archiva/jboss-web.xml";
  }
}
