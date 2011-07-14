# jww (2008-09-03): Deal with all of my virtual hosts in conf.d

class apache
{
  package { httpd: ensure => latest }

  service { httpd:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[httpd];
  }

  file { "/etc/httpd/conf.d/deflate.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/apache/deflate.conf",
    notify  => Service[httpd],
    require => Package[httpd];
  }

  if $architecture == "x86_64" {
    file { "/usr/lib64/httpd/modules/mod_jk.so":
      owner   => "root",
      group   => "root",
      mode    => 0755,
      ensure  => present,
      source  => "puppet:///modules/apache/mod_jk-1.2.28-httpd-2.2.X.x86_64.so",
      require => Package[httpd];
    }
  } else {
    file { "/usr/lib/httpd/modules/mod_jk.so":
      owner   => "root",
      group   => "root",
      mode    => 0755,
      ensure  => present,
      source  => "puppet:///modules/apache/mod_jk-1.2.28-httpd-2.2.X.i386.so",
      require => Package[httpd];
    }
  }

  define mod_jk($host = "localhost", $uris = ["/*"]) {
    include apache

    file { "/etc/httpd/conf.d/mod_jk.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("apache/mod_jk.conf.erb"),
      notify  => Service[httpd],
      require => Package[httpd];
    }

    file { "/etc/httpd/conf/uriworkermap.properties":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("apache/uriworkermap.properties.erb"),
      require => Package[httpd];
    }

    file { "/etc/httpd/conf/workers.properties":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("apache/workers.properties.erb"),
      require => Package[httpd];
    }
  }

  nagios::target::service { httpd: }

  firewall::rule { httpd: module => "apache" }

  selinux::policy { httpd-ext: module => "apache" }
}

class apache::secure inherits apache
{
  package { mod_ssl: ensure => latest }

  #package { mod_security: ensure => installed }

  firewall::rule { httpd-ssl: module => "apache" }
}
