import '/tmp/puppet/bootstrap.pp'

file { "/etc/puppet/puppet.conf":
  owner   => root,
  group   => root,
  mode    => 0755,
  ensure  => present,
  source  => "/tmp/puppet/puppet-agent.conf",
  require => Package["puppet"];
}
