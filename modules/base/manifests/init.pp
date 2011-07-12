class base
{
  case $operatingsystem {
    centos:  { include centos }
    fedora:  { include fedora }
    debian:  { include debian }
    default: { include centos }
  }

  file { "/etc/hosts.deny":
    owner  => "root",
    group  => "root",
    mode   => 0644,
    ensure => present,
    source => "puppet:///modules/base/hosts.deny";
  }

  service { network:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true;
  }
}

define ipforward()
{
  exec { "enable forwarding on $hostname":
    user    => "root",
    command => "/bin/echo 1 > /proc/sys/net/ipv4/ip_forward",
    unless  => "/bin/cat /proc/sys/net/ipv4/ip_forward | /bin/grep -q 1";
  }
}

define iproute($device = "eth0", $routes)
{
  file { "/etc/sysconfig/network-scripts/route-${device}":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    content => template("base/static_route.erb"),
    before  => Service[network],
    notify  => Service[network];
  }
}

define interface($mac = $macaddress_eth0, $address = $ipaddress_eth0,
                 $bootproto = "dhcp", $gateway = "",
                 $net_mask = "255.255.255.0")
{
  file { "/etc/sysconfig/networking/devices/ifcfg-${title}":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    content => $bootproto ? {
      "static" => template("base/ifcfg-static.erb"),
      "dhcp"   => template("base/ifcfg-dhcp.erb")
    },
    before  => Service[network],
    notify  => Service[network];
  }
}

define tcpwrapper($allow = "", $deny = "")
{
  if $allow {
    exec { "tcpwrapper-allow-$title":
      command => "/bin/echo '$title : $allow' >> /etc/hosts.allow",
      unless  => "/bin/grep -q ^'$title : $allow' /etc/hosts.allow";
    }
  } else {
    exec { "tcpwrapper-deny-$title":
      command => "/bin/echo '$title : $deny' >> /etc/hosts.deny",
      unless  => "/bin/grep -q ^'$title : $allow' /etc/hosts.deny";
    }
  }
}
