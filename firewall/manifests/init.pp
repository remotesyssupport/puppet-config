class iptables
{
  package { iptables: ensure => latest; }
  #service { iptables: ensure => running; }

  file { "/etc/rc.firewall":
    owner  => "root",
    group  => "root",
    mode   => 0600,
    ensure => present,
    source => "puppet:///modules/firewall/rc.firewall",
    notify => Exec[reset-firewall];
  }

  file { "/etc/flush.sh":
    owner  => "root",
    group  => "root",
    mode   => 0600,
    ensure => present,
    source => "puppet:///modules/firewall/flush.sh";
  }

  file { "/etc/firewall.d":
    owner  => "root",
    group  => "root",
    mode   => 0700,
    type   => directory,
    ensure => directory;
  }

  exec { reset-firewall:
    user        => "root",
    command     => "/bin/sh /etc/rc.firewall auto || /bin/sh /etc/rc.firewall flush",
    refreshonly => true,
    notify      => Exec["save-firewall"],
    require     => [ File["/etc/rc.firewall"],
                     File["/etc/firewall.d"] ];
  }

  exec { save-firewall:
    user        => "root",
    command     => "/sbin/service iptables save",
    refreshonly => true;
  }
}

class firewall
{
  case $operatingsystem {
    centos: { include iptables }
    darwin: { include ipfw }
    default: {}
  }

  define access ($device = "eth0", $address = $ipaddress_eth0) {
    file { "/etc/sysconfig/networking/${title}-${device}":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("firewall/interface.erb"),
      before  => Exec[reset-firewall];
    }
  }

  define pre ($module = false) {
    file { "/etc/firewall.d/$title.pre":
      owner  => "root",
      group  => "root",
      mode   => 0600,
      ensure => present,
      source => $module ? {
        false   => "puppet:///modules/$title/$title.pre",
        default => "puppet:///modules/$module/$title.pre"
      },
      notify => Exec[reset-firewall];
    }
  }

  define pre_tmpl ($module = false) {
    file { "/etc/firewall.d/$title.pre":
      owner   => "root",
      group   => "root",
      mode    => 0600,
      ensure  => present,
      content => $module ? {
        false   => template("$title/$title.pre.erb"),
        default => template("$module/$title.pre.erb")
      },
      notify  => Exec[reset-firewall];
    }
  }

  define rule ($module = false) {
    file { "/etc/firewall.d/$title.ipt":
      owner  => "root",
      group  => "root",
      mode   => 0600,
      ensure => present,
      source => $module ? {
        false   => "puppet:///modules/$title/$title.ipt",
        default => "puppet:///modules/$module/$title.ipt"
      },
      notify => Exec[reset-firewall];
    }
  }

  define rule_tmpl ($module = false) {
    file { "/etc/firewall.d/$title.ipt":
      owner   => "root",
      group   => "root",
      mode    => 0600,
      ensure  => present,
      content => $module ? {
        false   => template("$title/$title.ipt.erb"),
        default => template("$module/$title.ipt.erb")
      },
      notify  => Exec[reset-firewall];
    }
  }
}

class firewall::off
{
  service { iptables:
    ensure     => stopped,
    enable     => true,
    hasstatus  => true,
    hasrestart => true;
  }
}
