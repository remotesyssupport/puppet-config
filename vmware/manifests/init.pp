class vmware::server
{
  $packages = [ VMware-server ]

  package { $packages: ensure => installed }

  firewall::rule { vmware: }

  service { vmware:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package[VMware-server];
  }

  file { "/usr/lib/vmware/webAccess/tomcat/apache-tomcat-6.0.16/conf/server.xml":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/vmware/server.xml",
    notify  => Service[vmware],
    require => Package[VMware-server];
  }

  file { "/etc/vmware/hostd/proxy.xml":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/vmware/proxy.xml",
    notify  => Service[vmware],
    require => Package[VMware-server];
  }

  nagios::target::service { vmware: }

  # jww (2009-05-02): todo
  #selinux::policy { vmware: }
}

class vmware::vm
{
  include firewall::off
}
