class java_rhel
{
  $java_home = "/usr/java/default"

  package { jdk: ensure => latest }

  package { sun-javadb-common:
    ensure  => latest,
    require => Package[jdk];
  }
  package { sun-javadb-core:
    ensure  => latest,
    require => Package[jdk];
  }
  package { sun-javadb-client:
    ensure  => latest,
    require => Package[jdk];
  }

  if false {
    package { sun-javadb-demo:    ensure => latest }
    package { sun-javadb-docs:    ensure => latest }
    package { sun-javadb-javadoc: ensure => latest }
  }

  file { "/etc/profile.d/java.sh":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    content => template("java/java.sh.erb"),
    require => Package[jdk];
  }

  exec { "alternatives install java":
    user        => "root",
    command     => "/usr/sbin/alternatives --install /usr/bin/java java $java_home/bin/java 2",
    refreshonly => true,
    subscribe   => Package[jdk],
    require     => Package[jdk];
  }
}

class java
{
  case $operatingsystem {
    centos: { include java_rhel }
    fedora: { include java_rhel }
  }
}
