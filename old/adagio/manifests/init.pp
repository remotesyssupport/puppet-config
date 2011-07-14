class adagio
{
  include jboss
  include groovy

  package { unzip: ensure => latest }
  #package { "Adagio_App":
  #  ensure  => latest,
  #  require => Package[jboss];
  #}

  #file { "/usr/jboss/bin/install-adagio.sh":
  #  owner   => "root",
  #  group   => "root",
  #  mode    => 0644,
  #  ensure  => present,
  #  source  => "puppet:///modules/adagio/install-adagio.sh",
  #  require => [ Class[jboss], Package["Adagio_App"] ];
  #}
  #
  #exec { "install Adagio into JBoss":
  #  user    => "root",
  #  command => "/bin/sh /usr/jboss/bin/install-adagio.sh",
  #  timeout => 600,
  #  require => File["/usr/jboss/bin/install-adagio.sh"];
  #}

  file { "/usr/jboss/bin/adagioTest.groovy":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/adagio/adagioTest.groovy",
    require => Package[jboss];
  }

  $plugin_dir = $architecture ? {
    "x86_64" => "/usr/lib64/nagios/plugins",
    "i386"   => "/usr/lib/nagios/plugins"
  }

  @file { "$plugin_dir/check_adagio":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/adagio/check_adagio",
    require => Package[nagios-nrpe],
    tag     => "nagios_checks";
  }

  nagios::target::command { "check_adagio":
    command => "$plugin_dir/check_adagio -s localhost -p $hostname";
  }

  define csrportal($host = "127.0.0.1", $gateway, $statics = "/usr/adagio_csr") {
    file { $title:
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("adagio/csrportal.conf.erb"),
      notify  => Service[httpd],
      require => Package[httpd];
    }
  }

  define adminportal() {
    file { $title:
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("adagio/adminportal.conf.erb"),
      notify  => Service[httpd],
      require => Package[httpd];
    }
  }
}

class adagio::client
{
  #package { "Adagio_Lib": ensure => installed }
  
  file { "/usr/adagio":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    type    => directory,
    ensure  => directory;
  }
  
  define properties ($owner, $group, $provider_url) {
    file { "$title":
      owner   => "$owner",
      group   => "$group",
      mode    => 0644,
      content => template("adagio/jndi.properties.erb");
    }
  }
}
