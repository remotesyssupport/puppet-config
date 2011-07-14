class gitolite
{
  include git

  group { git: ensure => present }

  user { git:
    groups  => [ git ],
    home    => "/home/git",
    shell   => "/bin/sh",
    ensure  => present,
    require => Group[git];
  }
}
