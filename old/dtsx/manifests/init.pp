class dtsx
{
  include java
  include wine
  include xvfb
  include supervisor
  include adagio::client

  package { InDesign: ensure => installed }

  define admin($rmi_port = 7001) {
    include dtsx
    include nagios::target

    file { "/etc/supervisord.d/DTSXCluster$name.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      content => template("dtsx/DTSXCluster.ini.erb"),
      require => Package[wine];
    }

    supervisor::service { "DTSXCluster$name":
      ensure  => running,
      enable  => true;
    }
  }

  define indesign($screen) {
    exec { "install $title directory":
      user    => "indesign",
      cwd     => "/usr/indesign",
      timeout => 600,
      command => "/usr/bin/rsync -a .wine/ $title/",
      creates => "/usr/indesign/$title",
      require => Package[InDesign];
    }

    file { "/usr/indesign/$title/dosdevices/h:":
      ensure  => "/mnt/data",
      require => Exec["install $title directory"];
    }
    file { "/usr/indesign/$title/dosdevices/i:":
      ensure  => "/mnt/data",
      require => Exec["install $title directory"];
    }
    file { "/usr/indesign/$title/dosdevices/j:":
      ensure  => "/mnt/data",
      require => Exec["install $title directory"];
    }

    file { "/etc/supervisord.d/Xvfb$screen.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      content => template("dtsx/Xvfb.ini.erb"),
      require => Package[xorg-x11-server-Xvfb];
    }

    supervisor::service { "Xvfb$screen":
      ensure  => running,
      enable  => true;
    }
  }

  define server($port_localserver               = 8001,
                $flag_joincluster               = true,
                $period_adminsleeptime_seconds  = 9,
                $hostname_clustermanager        = localhost,
                $port_clustermanager            = 7001,
                $period_pulseinterval           = 60,
                $default_watermarktext          = "",
                $default_watermarkfont          = "",
                $default_watermarktextfontstyle = "",
                $distance_watermarkoffset       = 0.01,
                $percentage_watermarkopacity    = 25) {
    include dtsx

    file { "/tmp/dtsx$name":
      owner   => "indesign",
      group   => "indesign",
      mode    => 0700,
      type    => directory,
      ensure  => directory,
      require => Package[InDesign];
    }

    dtsx::indesign { "dtsx$name": screen => "$name" }

    file { "/usr/indesign/dtsx$name/dosdevices/o:":
      ensure  => "/tmp/dtsx$name",
      require => Dtsx::Indesign["dtsx$name"];
    }

    file { "/usr/indesign/dtsx$name/drive_c/servers/DTSX/dtsx-server.config":
      owner   => "indesign",
      group   => "indesign",
      mode    => 0600,
      ensure  => present,
      content => template("dtsx/dtsx-server.config.erb"),
      require => File["/usr/indesign/dtsx$name/dosdevices/o:"];
    }

    file { "/etc/supervisord.d/DTSX$name.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      content => template("dtsx/DTSX.ini.erb"),
      require => [ Package[wine],
                   File["/usr/indesign/dtsx$name/drive_c/servers/DTSX/dtsx-server.config"] ];
    }

    supervisor::service { "DTSX$name":
      ensure  => running,
      enable  => true;
    }
  }
}
