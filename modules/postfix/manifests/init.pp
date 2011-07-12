class postfix
{
  package { postfix: ensure => installed }

  file { "/etc/postfix/main.cf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    content => template("postfix/main.cf.erb"),
    notify  => Service[postfix],
    require => Package[postfix];
  }
  file { "/etc/postfix/master.cf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    content => template("postfix/master.cf.erb"),
    notify  => Service[postfix],
    require => Package[postfix];
  }

  service { postfix:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[postfix];
  }

  nagios::target::service { postfix: }

  firewall::rule { smtp: module => "postfix" }

  nagios::service { check_smtp: }

  tcpwrapper { smtpd: allow => "ALL"; }

  group { "mail": ensure => present }

  #File { "/etc/pki/tls/certs/ca.crt":
  #  owner   => "root",
  #  group   => "root",
  #  mode    => 0644,
  #  source  => "puppet:///modules/postfix/%h/ca.crt",
  #}
  #File { "/etc/pki/tls/certs/%h.crt":
  #  owner   => "root",
  #  mode    => 0644,
  #  group => "mail";
  #  source  => "puppet:///modules/postfix/%h/%h.crt",
  #}
  #File { "/etc/pki/tls/private/%h/%h.key":
  #  owner   => "root",
  #  group => "mail",
  #  mode  => 0440;
  #  source  => "puppet:///modules/postfix/%h/%h.key",
  #}

  user { "postfix":
    ensure  => present,
    groups  => [ "postfix", "mail" ],
    require => Package[postfix];
  }
}
