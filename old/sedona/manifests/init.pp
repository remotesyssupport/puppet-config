class sedona
{
  define config (
    $administrator,
    $net_domain,
    $net_name,
    $net_cluster,
    $net_mask,
    $internet_addr,
    $gateway_mask,
    $gateway_addr,
    $net_range,
    $db_name,
    $doc_path,
    $adagio_version,
    $userportal_version,
    $pts_version,
    $zips_version,
    $gw_1,
    $pm_1,
    $ds_1,
    $as_1,
    $fs_1,
    $ws_1,
    $aux_1,
    $dtsx_1,
    $dtsx_2,
    $zips_1,
    $pub_1,
    $srv_1_ip,
    $srv_2_ip,
    $gw_1_ip,
    $pm_1_ip,
    $ds_1_ip,
    $as_1_ip,
    $fs_1_ip,
    $ws_1_ip,
    $aux_1_ip,
    $dtsx_1_ip,
    $dtsx_2_ip,
    $zips_1_ip,
    $pub_1_ip
    ) {
    include base
    include puppet::client
    include centos::admin
    include ntp
    include sshd
    include nagios::target
    include selinux
    include postfix
    #include rsyslog                # jww (2010-05-11): too resource consumptive
  
    mailalias { "root":  recipient => "admin" }
    mailalias { "admin": recipient => "$administrator" }
  
    if $environment == "production" {
      @@file { "/etc/dnsmasq.d/${hostname}.conf":
        content => $fqdn ? {
          "$pm_1"   => "dhcp-host=$macaddress_eth1,$hostname,${pm_1_ip},24h\n",
          "$fs_1"   => "dhcp-host=$macaddress_eth1,$hostname,${fs_1_ip},24h\n",
          #"$ds_1"   => "dhcp-host=$macaddress,$hostname,${ds_1_ip},24h\n",
          #"$as_1"   => "dhcp-host=$macaddress,$hostname,${as_1_ip},24h\n",
          #"$aux_1"  => "dhcp-host=$macaddress,$hostname,${aux_1_ip},24h\n",
          "$dtsx_1" => "dhcp-host=$macaddress,$hostname,${dtsx_1_ip},24h\n",
          "$dtsx_2" => "dhcp-host=$macaddress,$hostname,${dtsx_2_ip},24h\n",
          "$zips_1" => "dhcp-host=$macaddress,$hostname,${zips_1_ip},24h\n",
          #"$ws_1"   => "dhcp-host=$macaddress,$hostname,${ws_1_ip},24h\n",
          "$pub_1"  => "dhcp-host=$macaddress_eth0,$hostname,${pub_1_ip},24h\n",
    
          # This entry simply causes a DHCP reservation to be created for
          # whatever IP address the host starts up with.
          default   => "dhcp-host=$macaddress,$hostname,$ipaddress,24h\n"
        },
        notify => Service[dnsmasq],
        tag    => "dnsmasq";
      }
  
      $plugin_dir = $architecture ? {
        "x86_64" => "/usr/lib64/nagios/plugins",
        "i386"   => "/usr/lib/nagios/plugins"
      }
  
      nagios::target::command { "check_dig_server":
        command => "$plugin_dir/check_dig -H $gw_1 -l $fqdn";
      }
    }
  
    @@host { "$fqdn":
      ip     => $fqdn ? {
        "$pm_1" => $environment ? { production  => $ipaddress_eth1,
                                    development => $ipaddress },
        "$fs_1" => $environment ? { production  => $ipaddress_eth1,
                                    development => $ipaddress },
        default  => $ipaddress
      },
      alias  => [ "$hostname" ],
      ensure => present;
    }
  
    host { "$dtsx_1":
      ip     => "${dtsx_1_ip}",
      alias  => [ "${net_name}-dtsx-1" ],
      ensure => present;
    }
    host { "$dtsx_2":
      ip     => "${dtsx_2_ip}",
      alias  => [ "${net_name}-dtsx-2" ],
      ensure => present;
    }
    host { "$zips_1":
      ip     => "${zips_1_ip}",
      alias  => [ "${net_name}-zips-1" ],
      ensure => present;
    }
  
    if $environment == "development" {
      Host <<| title != fqdn |>>
    }
  
    nagios::target::monitor { "$pm_1": }
  
    nagios::service { check_root:
      command => "check_nrpe",
      args    => "check_root";
    }
    nagios::service { check_hda1:
      command => "check_nrpe",
      args    => "check_hda1";
    }
  
    tcpwrapper { nrpe: allow => "127.0.0.1, $net_cluster." }
    tcpwrapper { ALL:  allow => "127.0.0.1, $net_cluster." }
  }

  define puppetmaster
  {
    # This node inherits from abcdefault, and not abcslave, because all
    # abcslave's send their logs here.
  
    include puppet::server::stored_configs
    include nagios::monitor
    include centos::devel
  
    #include rsyslog
    #rsyslog::server { "${net_range}": }
  
    host { "localhost.localdomain":
      ip     => "127.0.0.1",
      alias  => [ "localhost", "puppet" ],
      ensure => present;
    }
  
    file { "/var/www/html/index.html":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      content => "\n",
      ensure  => present,
      require => Package[httpd];
    }
  
    postgres::access { "${net_range}": method => "trust sameuser" }
  }

class abcgateway
{
  ###########################################################################

  include dnsmasq

  Host <<| |>>
  File <<| tag == "dnsmasq" |>>

  firewall::pre_tmpl { masquerade: module => "abc" }
  ipforward { enabled: }

  ###########################################################################

  if $environment == "production" {
    include openvpn::bridge

    # In the production environment, the gateway is also the OpenVPN entry
    # point, giving Ethernet-bridged network access to the hosts within the
    # ABC rack.  This is really the only way to access them, other than the
    # public web server, and also emergency SSH on the internal interface.

    file { "/etc/openvpn/server.conf":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      notify  => Service[openvpn],
      content => template("abc/server.conf.erb");
    }

    file { "/etc/openvpn/keys":
      owner   => "root",
      group   => "root",
      mode    => 0700,
      type    => directory,
      ensure  => directory,
      recurse => true,
      source  => "puppet:///modules/abc/keys";
    }
  }

  ###########################################################################

  include apache::secure

  # Because the gateway and the puppetmaster are two different machines, the
  # gateway is configured using Apache to proxy any HTTP requests directly to
  # the puppetmaster.  This lets people access the Drupal-based Admin Portal.

  #package { mod_security: ensure => latest }

  #file { "/etc/httpd/conf.d/proxy.conf":
  #  owner   => "root",
  #  group   => "root",
  #  mode    => 0644,
  #  ensure  => present,
  #  content => template("abc/proxy.conf.erb"),
  #  notify  => Service[httpd],
  #  require => Package[httpd];
  #}

  abccsrportal::proxy { "/etc/httpd/conf.d/csrportal.conf":
    gateway => $fqdn;
  }
  abcadminportal::proxy { "/etc/httpd/conf.d/adminportal.conf": }

  file { "/etc/httpd/conf.d/ssl.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    source  => "puppet:///modules/abc/ssl.conf",
    ensure  => present,
    notify  => Service[httpd],
    require => Package[httpd];
  }

  ###########################################################################
}

class abcfileserver
{
  include samba::server

  if $environment == "development" {
    mount { "/mnt/data":
      pass    => '3',
      device  => '/dev/hdb1',
      target  => '/etc/fstab',
      dump    => '1',
      ensure  => 'mounted',
      fstype  => 'ext3',
      options => 'defaults'
    }
  }

  nfs::server::exports { "/mnt":
    domain_name   => "$net_domain",
    nobody_user   => "nobody",
    nobody_group  => "nobody",
    shares        => [ "data" ],
    share_access  => "${net_range}",
    share_options => "rw,sync,all_squash,anonuid=99,anongid=99",
    require       => $environment ? {
      production  => Class[Samba::Server],
      development => Mount["/mnt/data"]
    };
  }
}

class abcdatabase
{
  include db2

  file { "/srv/db2":
    owner   => "db2inst1",
    group   => "db2grp1",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => Package[db2];
  }

  db2::database { $db_name:
    require => File["/srv/db2"];
  }

  cron { "db2dump":
    ensure  => present,
    command => "/usr/db2/db2dump $db_name /srv/db2 > /dev/null 2>&1",
    user    => "db2inst1",
    hour    => 4,
    minute  => 0,
    require => File["/usr/db2/db2dump"];
  }

  file { "/srv/db2/$db_name":
    owner   => "db2inst1",
    group   => "db2grp1",
    mode    => 0755,
    type    => directory,
    ensure  => directory,
    require => File["/srv/db2"];
  }

  nfs::client::setup { "$net_domain":
    nobody_user  => "db2inst1",
    nobody_group => "db2grp1",
    require      => Db2::Database[$db_name];
  }

  nfs::client::mount { "$doc_path":
    host  => "$fs_1",
    share => "$doc_path";
  }
}

class abcappserver
{
  include adagio
  include abccsrportal

  #$opts = "-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=$as_1 -Djava.rmi.server.useLocalHostname=true -XX:MaxPermSize=256m -javaagent:jboss-profiler.jar -Djboss-profiler.properties=jboss-profiler.properties"
  $opts = "-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"

  jboss::server { $fqdn:
    serverid   => 1,
    options    => $environment ? {
      production  => "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -XX:MaxPermSize=512m",
      development => $opts
    },
    min_memory => $environment ? {
      production  => "4096m",
      development => "2048m"
    },
    max_memory => $environment ? {
      production  => "4096m",
      development => "2048m"
    };
  }

  jboss::logger { "$pm_1": }
  jboss::webloader { "true": }

  db2::license { "/usr/jboss/server/default/lib":
    owner   => "jboss",
    group   => "jboss",
    require => Package[jboss];
  }

  abccsrportal::app { adagio_csr:
    container            => jboss,
    migration_uri        => "db2://$ds_1_ip:50000/$db_name:currentSchema=MIGRATION;",
    migration_user       => "db2inst1",
    migration_password   => "db2inst1";
  }

  file { "/usr/jboss/server/default/deploy/csr.war":
    ensure  => "/usr/adagio_csr",
    require => Package[ABC_CSRPortal];
  }
}

class abcaux
{
  include adagio::client
  include supervisor
  include groovy

  adagio::client::properties { "/usr/adagio/jndi.properties":
    owner        => "root",
    group        => "root",
    provider_url => "jnp://$as_1:1099";
  }

  db2::license { "/usr/adagio":
    owner   => "root",
    group   => "root",
    require => Package["Adagio_Lib"];
  }

  define event_listener ($user_name, $password, $schema_name, $server_ids) {
    file { "/etc/supervisord.d/ClearServerSession.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/ClearServerSession.ini.erb");
    }

    file { "/usr/adagio/ClearServerSession.groovy":
      owner   => "root",
      group   => "root",
      mode    => 0755,
      ensure  => present,
      content => template("abc/ClearServerSession.groovy.erb");
    }

    supervisor::service { ClearServerSession:
      ensure  => running,
      enable  => true;
    }
  }

  define approval_server($serverid) {
    file { "/etc/supervisord.d/ApprovalServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/ApprovalServer.ini.erb");
    }

    supervisor::service { ApprovalServer:
      ensure  => running,
      enable  => true;
    }
  }

  define billing_server($serverid) {
    file { "/etc/supervisord.d/BillingServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/BillingServer.ini.erb");
    }

    supervisor::service { BillingServer:
      ensure  => running,
      enable  => true;
    }
  }

  define fax_event_router_server($serverid) {
    file { "/etc/supervisord.d/FaxEventRouterServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/FaxEventRouterServer.ini.erb");
    }
  
    supervisor::service { FaxEventRouterServer:
      ensure  => running,
      enable  => true;
    }
  }

  define grid_composer($serverid) {
    file { "/etc/supervisord.d/GridComposer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/GridComposer.ini.erb");
    }

    supervisor::service { GridComposer:
      ensure  => running,
      enable  => true;
    }
  }

  define order_closer($serverid) {
    file { "/etc/supervisord.d/OrderCloser.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/OrderCloser.ini.erb");
    }

    supervisor::service { OrderCloser:
      ensure  => running,
      enable  => true;
    }
  }

  define payment_transaction_server($serverid) {
    package { "PTS": ensure => installed }

    file { "/etc/supervisord.d/PaymentTransactionServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/PaymentTransactionServer.ini.erb");
    }

    file { "/etc/supervisord.d/ClearServerSession.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/ClearServerSession.ini.erb");
    }

    supervisor::service { PaymentTransactionServer:
      ensure  => running,
      enable  => true;
    }
  }

  define receipt_process_server($serverid) {
    file { "/etc/supervisord.d/ReceiptProcessServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/ReceiptProcessServer.ini.erb");
    }

    supervisor::service { ReceiptProcessServer:
      ensure  => running,
      enable  => true;
    }
  }

  define grid_setter($serverid) {
    include dtsx                # bring in everything that a DTSX server uses
  
    dtsx::indesign { "gridsetter":  screen => "1" }
  
    file { "/usr/indesign/gridsetter/drive_c/servers/Adagio":
      owner   => "indesign",
      group   => "indesign",
      mode    => 0755,
      type    => directory,
      ensure  => directory,
      require => Dtsx::Indesign["gridsetter"];
    }
  
    $screen = 1
  
    file { "/etc/supervisord.d/GridSetter.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/GridSetter.ini.erb"),
      require => Dtsx::Indesign["gridsetter"];
    }
  
    supervisor::service { GridSetter:
      ensure  => running,
      enable  => true;
    }
  }

  define proof_delivery_server($serverid) {
    include dtsx                # bring in everything that a DTSX server uses
  
    dtsx::indesign { "proofdeliveryserver": screen => "2" }
  
    $screen = 2
  
    file { "/etc/supervisord.d/ProofDeliveryServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("abc/ProofDeliveryServer.ini.erb"),
      require => Dtsx::Indesign["proofdeliveryserver"];
    }
  
    supervisor::service { ProofDeliveryServer:
      ensure  => running,
      enable  => true;
    }
  }
}

#class abcdtsx
#{
#  dtsx::admin { 1: rmi_port => 9101 }
#  dtsx::admin { 2: rmi_port => 9102 }
#
#  dtsx::server { 1:
#    port_localserver        => 9901,
#    hostname_clustermanager => "$dtsx_1",
#    port_clustermanager     => 9101,
#  }
#
#  if $environment == "production" {
#    dtsx::server { 2:
#      port_localserver        => 9902,
#      hostname_clustermanager => "$dtsx_1",
#      port_clustermanager     => 9101,
#    }
#    dtsx::server { 3:
#      port_localserver        => 9903,
#      hostname_clustermanager => "$dtsx_1",
#      port_clustermanager     => 9101,
#    }
#    dtsx::server { 4:
#      port_localserver        => 9904,
#      hostname_clustermanager => "$dtsx_1",
#      port_clustermanager     => 9101,
#    }
#    dtsx::server { 5:
#      port_localserver        => 9905,
#      hostname_clustermanager => "$dtsx_1",
#      port_clustermanager     => 9101,
#    }
#    dtsx::server { 6:
#      port_localserver        => 9906,
#      hostname_clustermanager => "$dtsx_1",
#      port_clustermanager     => 9101,
#    }
#  }
#    
#  if $environment == "production" {
#    dtsx::server { 7:
#      port_localserver        => 9907,
#      hostname_clustermanager => "$dtsx_2",
#      port_clustermanager     => 9102,
#    }
#
#    dtsx::server { 8:
#      port_localserver        => 9908,
#      hostname_clustermanager => "$dtsx_2",
#      port_clustermanager     => 9102,
#    }
#  } else {
#    dtsx::server { 7:
#      port_localserver        => 9907,
#      hostname_clustermanager => "$dtsx_1",
#      port_clustermanager     => 9102,
#    }
#  }
#}

class abctomcat
{
  include abcuserportal
  include abcadminportal
  #include abccsrportal

  tomcat::server  { "$ws_1":
    options    => $environment ? {
      production  => "-Dsun.rmi.dgc.client.gcInterval=1800000 -Dsun.rmi.dgc.server.gcInterval=1800000 -XX:+UseParallelGC -XX:ParallelGCThreads=4",
      development => "-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"
    },
    min_memory => $environment ? { production  => "1024m",
                                   development => "768m" },
    max_memory => $environment ? { production  => "1024m",
                                   development => "768m" };
  }
  tomcat::manager { "admin": password => "admin" }

  abcuserportal::app { ABC_UserPortal:
    abc_site_uri         => "db2://$ds_1_ip:50000/$db_name:currentSchema=ABC_SITE;",
    abc_site_user        => "db2inst1",
    abc_site_password    => "db2inst1",
    abc_catalog_uri      => "db2://$ds_1_ip:50000/$db_name:currentSchema=ABC_CATALOG;",
    abc_catalog_user     => "db2inst1",
    abc_catalog_password => "db2inst1",
    migration_uri        => "db2://$ds_1_ip:50000/$db_name:currentSchema=MIGRATION;",
    migration_user       => "db2inst1",
    migration_password   => "db2inst1",
    mysql_abc_uri        => "mysql://localhost/abc_userportal",
    mysql_abc_user       => "abc_userportal",
    mysql_abc_password   => "abc_userportal",
    mysql_adc_uri        => "mysql://localhost/adc_userportal",
    mysql_adc_user       => "adc_userportal",
    mysql_adc_password   => "adc_userportal";
  }
}

class abcpublic
{
  include abcstatic

  abcstatic::site { "americanbusinesscard":
    server_name    => "www.americanbusinesscard.com",
    server_alias   => "americanbusinesscard.com",
    server_admin   => "webmaster@americanbusinesscard.com",
    proxy_hosts  => [ "${ws_1}:8080" ];
  }
}
}

node 'abc-p1-srv-1.corp.smartceg.com',
     'abc-d1-srv-1.corp.smartceg.com' inherits abcdefault
{
  include abcpuppetmaster
  include abcgateway
  include abcdatabase
  include abcappserver

  if $environment == "production" {
    #include vmware::server
    include firewall
    include psacct
  } else {
    include vmware::vm
  }

  selinux::state { disabled: }

  Nagios::Target::Monitor["$pm_1"] {
    root_volume => "/dev/mapper/VolGroup01-LogVol00"
  }
  Nagios::Service[check_hda1] {
    args => "check_sda1"
  }

  interface { eth0: }
  interface { eth1:
    bootproto => "static",
    address   => $srv_1_ip;
  }

  firewall::access { public:
    device  => "eth0";
  }
  firewall::access { private:
    device  => "eth1",
    address => $srv_1_ip;
  }

  apache::mod_jk { node1:
    host    => "localhost",
    uris    => [ "/csr/cgi/*",
                 "/csr/dts/cgi/*",
                 "/csr/2/cgi/*" ];
  }

  exec { canonicaldb:
    user    => "root",
    command => "/usr/sbin/postmap /etc/postfix/canonical",
    unless  => "/usr/bin/test /etc/postfix/canonical.db -nt /etc/postfix/canonical";
  }

  file { "/etc/postfix/canonical":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    source  => "puppet:///modules/abc/canonical",
    ensure  => present,
    notify  => Exec[canonicaldb],
    require => Package[postfix];
  }

  Nagios::Target::Monitor["$pm_1"] {
      max_procs_warn => 250,
      max_procs_crit => 300
  }
}

node 'abc-p1-srv-2.corp.smartceg.com',
     'abc-d1-srv-2.corp.smartceg.com' inherits abcslave
{
  include abcfileserver
  include abctomcat

  if $environment == "production" {
    include vmware::server
    include firewall

    ipforward { enabled: }
  
    iproute { external:
      device  => "eth1",
      address => "default",
      gateway => $srv_1_ip;
    }
  
    iproute { internal:
      device  => "eth0",
      address => "172.24.8.0/24",
      gateway => "10.9.19.120";
    }
  
    interface { eth1:
      bootproto => "static",
      address   => $srv_2_ip;
    }
  
    firewall::access { public:
      device  => "eth0";
    }

    firewall::access { private:
      device  => "eth1",
      address => $srv_2_ip;
    }
  } else {
    include vmware::vm
  }

  selinux::state { disabled: }

  interface { eth0: }

  Nagios::Service[check_hda1] {
    args => "check_sda1"
  }

  firewall::pre_tmpl { forward: module => "abc" }

  # MySQL and Tomcat need to be restarted each day because Tomcat doesn't give
  # up MySQL connections fast enough and the system periodically runs out of
  # free connections and even free file handles.
  cron { "restart mysql":
    ensure  => present,
    command => "/sbin/service mysqld restart > /dev/null",
    user    => "root",
    hour    => 4,
    minute  => 0;
  }
  cron { "restart tomcat":
    ensure  => present,
    command => "/usr/bin/ctl restart tomcat > /dev/null",
    user    => "root",
    hour    => 4,
    minute  => 15;
  }

  Nagios::Target::Monitor["$pm_1"] {
    max_procs_warn => 225,
    max_procs_crit => 260
  }

  include abcaux

  abcaux::billing_server             { "BillingServer":            serverid => 4 }
  abcaux::approval_server            { "ApprovalServer":           serverid => 6 }
  abcaux::grid_composer              { "GridComposer":             serverid => 7 }
  abcaux::order_closer               { "OrderCloser":              serverid => 11 }

  if $environment == "production" {
    # Only run the automated billing service in production use
    abcaux::receipt_process_server     { "ReceiptProcessServer":     serverid => 13 }
    abcaux::payment_transaction_server { "PaymentTransactionServer": serverid => 0 }
  }

  # jww (2010-01-05): These two run in a Windows-like environment, to use
  # InDesign, PhotoShop and ZetaFAX.
  #proof_delivery_server      { "ProofDeliveryServer":      serverid => 2 }
  #fax_event_router_server    { "FaxEventRouterServer":     serverid => 5 }
  #grid_setter                { "GridSetter":               serverid => 8 }

  cron { "restart gridcomposer":
    ensure  => present,
    command => "/usr/bin/ctl restart GridComposer > /dev/null",
    user    => "root",
    hour    => 5,
    minute  => 0;
  }
}

node 'abc-p1-pub-1.corp.smartceg.com',
     'abc-d1-pub-1.corp.smartceg.com' inherits abcslave
{
  include abcpublic

  if $environment == "production" {
    include firewall

    interface { eth1:
      bootproto => "static",
      address   => $internet_addr,
      net_mask  => $gateway_mask,
      gateway   => $gateway_addr;
    }

    firewall::access { public:
      device    => "eth1",
      address   => $internet_addr;
    }
  } else {
    include vmware::vm
  }

  selinux::state { enforcing: }

  Nagios::Service[check_hda1] {
    args => "check_root"
  }

  interface { eth0:
    bootproto => "static",
    address   => $pub_1_ip;
  }

  firewall::access { private:
    device    => "eth0",
    address   => $pub_1_ip;
  }
}
