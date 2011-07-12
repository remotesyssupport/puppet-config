class sudo
{
  package { sudo: ensure => installed }

  file { "/etc/sudoers":
    owner   => "root",
    group   => "root",
    mode    => 0440,
    ensure  => present,
    source  => "puppet:///modules/sudo/sudoers",
    require => Package[sudo];
  }
}
