class supervisor
{
  include python

  #file { "/var/log/supervisord":
  #  owner  => "root",
  #  group  => "root",
  #  mode   => 0640,
  #  type   => directory,
  #  ensure => directory;
  #}

  file { "/etc/supervisord.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/supervisor/supervisord.conf",
    notify  => Service[supervisor];
  }

  file { "/etc/init.d/supervisor":
    owner  => "root",
    group  => "root",
    mode   => 0755,
    ensure => present,
    source => "puppet:///modules/supervisor/supervisor.init",
  }

  file { "/usr/bin/ctl":
    owner  => "root",
    group  => "root",
    mode   => 0755,
    ensure => present,
    source => "puppet:///modules/supervisor/ctl",
  }

  file { "/etc/supervisord.d":
    owner  => "root",
    group  => "root",
    mode   => 0755,
    type   => directory,
    ensure => directory;
  }

  @file { "/var/run/supervisor.sock":
    owner   => "root",
    group   => "nagios",
    mode    => 0775,
    ensure  => present,
    require => Service[supervisor];
  }

  $plugin_dir = $architecture ? {
    "x86_64" => "/usr/lib64/nagios/plugins",
    "i386"   => "/usr/lib/nagios/plugins"
  }

  @file { "$plugin_dir/check_ctl":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/supervisor/check_ctl",
    require => Package[nagios-nrpe],
    tag     => "nagios_checks";
  }

  pymod { supervisor: }

  service { supervisor:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => [ Pymod[supervisor],
                    File["/etc/supervisord.conf"],
                    File["/etc/supervisord.d"],
                    File["/etc/init.d/supervisor"] ];
  }

  nagios::target::service { supervisor: }

  define service ($enable = "true", $ensure = "running") {
    case $ensure {
      running: {
        exec { "supervisor::service start $title":
          command => "/usr/bin/supervisorctl start $title",
          unless  => "/usr/bin/supervisorctl status $title | /bin/grep -q RUNNING",
          require => [ Service[supervisor],
                       File["/etc/supervisord.d/$title.ini"] ];
        }

        nagios::target::command { "check_$title":
          command => "$plugin_dir/check_ctl -s $title";
        }
      }
      stopped: {
        exec { "supervisor::service stop $title":
          command => "/usr/bin/supervisorctl stop $title",
          onlyif  => "/usr/bin/supervisorctl status $title | /bin/grep -q RUNNING",
          require => [ Service[supervisor],
                       File["/etc/supervisord.d/$title.ini"] ];
        }
      }
    }
  }
}
