class bizstatic
{
  include apache::secure

  package { unzip: ensure => installed }

  #package { BIZ_Static:
  #  ensure  => latest,
  #  require => [ Package[httpd], Package[unzip] ];
  #}

  define site(server_name, server_alias, server_admin,
              log_level   = "notice",
              proxy_hosts = [ "localhost:8080" ]) {
    file { "/etc/pki/tls/private/$title.key":
      owner   => "apache",
      group   => "root",
      mode    => 0600,
      ensure  => present,
      source  => "puppet:///modules/bizstatic/$title.key";
    }
    
    file { "/etc/pki/tls/certs/$title.crt":
      owner   => "apache",
      group   => "root",
      mode    => 0600,
      ensure  => present,
      source  => "puppet:///modules/bizstatic/$title.crt";
    }
    
    file { "/etc/pki/tls/certs/$title.ca-bundle":
      owner   => "apache",
      group   => "root",
      mode    => 0600,
      ensure  => present,
      source  => "puppet:///modules/bizstatic/$title.ca-bundle";
    }
    
    file { "/etc/httpd/conf.d/$title.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("bizstatic/$title.conf.erb"),
      notify  => Service[httpd]
      # , require => Package[BIZ_Static];
    }
    
    file { "/etc/httpd/${title}_body.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("bizstatic/${title}_body.conf.erb"),
      notify  => Service[httpd],
      require => File["/etc/httpd/conf.d/$title.conf"];
    }

    apache::mod_jk { node1:
      host    => $proxy_hosts,
      uris    => [ "/bizcard.com/*" ];
    }

    nagios::target::command { "check_homepage":
      command => "$plugin_dir/check_http -H $server_name -I 127.0.0.1 -w 5 -c 10 / -s \"BIZCard is a registered trademark of BIZCard\"";
    }
    nagios::target::command { "check_catalog":
      command => "$plugin_dir/check_http -H www.bizcard.com -I 127.0.0.1 -w 5 -c 10 -u /catalog -s \"shell/standard/bizcard\"";
    }
  }
}
