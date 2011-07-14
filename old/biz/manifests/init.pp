import "base"

node bizdefs
{
  $administrator = "johnw@3dex.com"
  $net_domain    = "corp.smartceg.com"

  case $hostname {
    /^biz-p[12]/: {
      $server_type   = "production"
      $net_name      = "biz-p2"
      $net_cluster   = "10.100.1"
      $net_mask      = "255.255.255.0"
  
      $internet_addr = "74.206.105.135"
      $gateway_addr  = "74.206.96.137"
      $gateway_mask  = "255.255.0.0"
    }
    /^biz-d1/: {
      $server_type   = "virtual"
      $net_name      = "biz-d1"
      $net_cluster   = "172.16.6"
      $net_mask      = "255.255.255.0"
    }
    /^biz-d2/: {
      $server_type   = "development"
      $net_name      = "biz-d2"
      $net_cluster   = "172.24.8"
      $net_mask      = "255.255.255.0"
    }
  }
  $net_range = "${net_cluster}.0/24"

  $db_name            = "BIZ_P1"
  $doc_path           = "/mnt/data"
  $adagio_version     = "2.9.2-SNAPSHOT"
  $userportal_version = "1.0.0-SNAPSHOT"
  $pts_version        = "1.4.0"
  $zips_version       = "1.4.0"

  $gw_1   = "${net_name}-srv-1.${net_domain}"  # gw: gateway
  $pm_1   = "${net_name}-srv-1.${net_domain}"  # pm: puppet master
  $ds_1   = "${net_name}-srv-1.${net_domain}"  # ds: data server (DB2)
  $as_1   = "${net_name}-srv-1.${net_domain}"  # as: application server (JBoss)
  $fs_1   = "${net_name}-srv-2.${net_domain}"  # fs: file server (NFS4)
  $ws_1   = "${net_name}-srv-2.${net_domain}"  # ws: web server (Apache, Tomcat6)
  $aux_1  = "${net_name}-srv-2.${net_domain}"  # aux: satellite servers
  $dtsx_1 = "${net_name}-dtsx-1.${net_domain}" # DTSX server (InDesign)
  $dtsx_2 = "${net_name}-dtsx-2.${net_domain}" # DTSX server (InDesign)
  $zips_1 = "${net_name}-zips-1.${net_domain}" # Zips server (Photoshop)
  $pub_1  = "${net_name}-pub-1.${net_domain}"  # pub: "public entry"

  if $server_type == "production" {
    $srv_1_ip  = "${net_cluster}.201"
    $srv_2_ip  = "${net_cluster}.202"
  } else {
    if $server_type == "virtual" {
      $srv_1_ip  = "${net_cluster}.21"
      $srv_2_ip  = "${net_cluster}.22"
    } else {
      $srv_1_ip  = "${net_cluster}.125"
      $srv_2_ip  = "${net_cluster}.153"
    }
  }

  $gw_1_ip   = $srv_1_ip
  $pm_1_ip   = $srv_1_ip
  $ds_1_ip   = $srv_1_ip
  $as_1_ip   = $srv_1_ip
  $fs_1_ip   = $srv_2_ip
  $ws_1_ip   = $srv_2_ip
  $aux_1_ip  = $srv_2_ip
  $dtsx_1_ip = "${net_cluster}.111"
  $dtsx_2_ip = "${net_cluster}.102"
  $zips_1_ip = "${net_cluster}.117"
  $pub_1_ip  = "${net_cluster}.61"

  $srv_1_mac  = $macaddress
  $pm_1_mac   = $srv_1_mac
  $srv_2_mac  = $macaddress
  $fs_1_mac   = $srv_2_mac
  $pub_1_mac  = $macaddress_eth0
}

node bizdefault inherits bizdefs
{
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

  if $server_type == "production" {
    @@file { "/etc/dnsmasq.d/${hostname}.conf":
      content => $fqdn ? {
        "$pm_1"   => "dhcp-host=$pm_1_mac,$hostname,${pm_1_ip},24h\n",
        "$fs_1"   => "dhcp-host=$fs_1_mac,$hostname,${fs_1_ip},24h\n",
        #"$ds_1"   => "dhcp-host=$macaddress,$hostname,${ds_1_ip},24h\n",
        #"$as_1"   => "dhcp-host=$macaddress,$hostname,${as_1_ip},24h\n",
        #"$aux_1"  => "dhcp-host=$macaddress,$hostname,${aux_1_ip},24h\n",
        "$dtsx_1" => "dhcp-host=$macaddress,$hostname,${dtsx_1_ip},24h\n",
        "$dtsx_2" => "dhcp-host=$macaddress,$hostname,${dtsx_2_ip},24h\n",
        "$zips_1" => "dhcp-host=$macaddress,$hostname,${zips_1_ip},24h\n",
        #"$ws_1"   => "dhcp-host=$macaddress,$hostname,${ws_1_ip},24h\n",
        "$pub_1"  => "dhcp-host=$pub_1_mac,$hostname,${pub_1_ip},24h\n",
  
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
      "$pm_1" => $pm_1_ip,
      "$fs_1" => $fs_1_ip,
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

  if $server_type != "production" {
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

node bizslave inherits bizdefault
{
  #rsyslog::client { "$pm_1": }
}

class bizpuppetmaster
{
  # This node inherits from bizdefault, and not bizslave, because all
  # bizslave's send their logs here.

  include puppet::server::stored_configs
  #include nagios::monitor
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

class bizgateway
{
  ###########################################################################

  include dnsmasq

  Host <<| |>>
  File <<| tag == "dnsmasq" |>>

  firewall::pre_tmpl { masquerade: module => "biz" }
  ipforward { enabled: }

  # ###########################################################################
  # 
  # if $server_type == "production" {
  #   include openvpn::bridge
  # 
  #   # In the production environment, the gateway is also the OpenVPN entry
  #   # point, giving Ethernet-bridged network access to the hosts within the
  #   # BIZ rack.  This is really the only way to access them, other than the
  #   # public web server, and also emergency SSH on the internal interface.
  # 
  #   file { "/etc/openvpn/server.conf":
  #     owner   => "root",
  #     group   => "root",
  #     mode    => 0644,
  #     ensure  => present,
  #     notify  => Service[openvpn],
  #     content => template("biz/server.conf.erb");
  #   }
  # 
  #   file { "/etc/openvpn/keys":
  #     owner   => "root",
  #     group   => "root",
  #     mode    => 0700,
  #     type    => directory,
  #     ensure  => directory,
  #     recurse => true,
  #     source  => "puppet:///modules/biz/keys";
  #   }
  # }

  ###########################################################################

  include apache::secure

  adagio::csrportal { "/etc/httpd/conf.d/csrportal.conf":
    gateway => $fqdn;
  }
  adagio::adminportal { "/etc/httpd/conf.d/adminportal.conf": }

  file { "/etc/httpd/conf.d/ssl.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    source  => "puppet:///modules/biz/ssl.conf",
    ensure  => present,
    notify  => Service[httpd],
    require => Package[httpd];
  }

  ###########################################################################
}

class bizfileserver
{
  include samba::server

  if $server_type == "virtual" {
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

  file { "/mnt/dtsx":
    owner   => "nobody",
    group   => "nobody",
    mode    => 0755,
    type    => directory,
    ensure  => directory;
  }

  mount { "/mnt/dtsx":
    pass    => '3',
    device  => "//${ds_1}/dtsx",
    target  => '/etc/fstab',
    dump    => '1',
    ensure  => 'mounted',
    fstype  => 'cifs',
    options => 'user=nobody,pass=nobody',
    require => File["/mnt/dtsx"];
  }

  if $server_type != "bootstrap" {
    nfs::server::exports { "/mnt":
      domain_name   => "$net_domain",
      nobody_user   => "nobody",
      nobody_group  => "nobody",
      shares        => [ "data" ],
      share_access  => "${net_range}",
      share_options => "rw,sync,all_squash,anonuid=99,anongid=99",
      require       => $server_type ? {
        production  => Class[Samba::Server],
        development => Class[Samba::Server],
        virtual     => Mount["/mnt/data"]
      };
    }
  }
}

class bizdatabase
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

class bizappserver
{
  include adagio
  include samba::server         # for exporting /mnt/dtsx

  #$opts = "-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=$as_1 -Djava.rmi.server.useLocalHostname=true -XX:MaxPermSize=256m -javaagent:jboss-profiler.jar -Djboss-profiler.properties=jboss-profiler.properties"
  $opts = "-Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"

  jboss::server { $fqdn:
    serverid   => 0,
    options    => $server_type ? {
      production  => "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit",
      development => $opts,
      virtual     => $opts
    },
    min_memory => $server_type ? {
      production  => "4096m",
      development => "2048m",
      virtual     => "2048m"
    },
    max_memory => $server_type ? {
      production  => "4096m",
      development => "2048m",
      virtual     => "2048m"
    };
  }

  jboss::logger { "$pm_1": }

  db2::license { "/usr/jboss/server/default/lib":
    owner   => "jboss",
    group   => "jboss",
    require => Package[jboss];
  }

  file { "/mnt/dtsx":
    owner   => "nobody",
    group   => "nobody",
    mode    => 0755,
    type    => directory,
    ensure  => directory;
  }

  # nfs::server::exports { "/mnt":
  #   domain_name   => "$net_domain",
  #   nobody_user   => "nobody",
  #   nobody_group  => "nobody",
  #   shares        => [ "dtsx" ],
  #   share_access  => "${net_range}",
  #   share_options => "rw,sync,all_squash,anonuid=99,anongid=99",
  #   require       => Class[Samba::Server];
  # }
}

class bizaux
{
  include adagio::client
  include supervisor

  adagio::client::properties { "/usr/adagio/jndi.properties":
    owner        => "root",
    group        => "root",
    provider_url => "jnp://$as_1:1099";
  }

  db2::license { "/usr/adagio":
    owner   => "root",
    group   => "root",
    require => Class[Adagio::Client];
  }

  define approval_server($serverid) {
    file { "/etc/supervisord.d/ApprovalServer.ini":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("biz/ApprovalServer.ini.erb");
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
      content => template("biz/BillingServer.ini.erb");
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
      content => template("biz/FaxEventRouterServer.ini.erb");
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
      content => template("biz/GridComposer.ini.erb");
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
      content => template("biz/OrderCloser.ini.erb");
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
      content => template("biz/PaymentTransactionServer.ini.erb");
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
      content => template("biz/ReceiptProcessServer.ini.erb");
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
      content => template("biz/GridSetter.ini.erb"),
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
      content => template("biz/ProofDeliveryServer.ini.erb"),
      require => Dtsx::Indesign["proofdeliveryserver"];
    }
  
    supervisor::service { ProofDeliveryServer:
      ensure  => running,
      enable  => true;
    }
  }
}

class biztomcat
{
  include bizuserportal

  if $server_type != "bootstrap" {
    tomcat::server  { "$ws_1":
      options    => $server_type ? {
        production  => "-XX:MaxPermSize=256m -Dsun.rmi.dgc.client.gcInterval=1800000 -Dsun.rmi.dgc.server.gcInterval=1800000 -XX:+UseParallelGC -XX:ParallelGCThreads=4",
        development => "-XX:MaxPermSize=256m -Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n",
        virtual     => "-XX:MaxPermSize=256m -Xdebug -Xrunjdwp:transport=dt_socket,address=8787,server=y,suspend=n"
      },
      min_memory => $server_type ? {
        production  => "1024m",
        development => "768m",
        virtual     => "768m"
      },
      max_memory => $server_type ? {
        production  => "1024m",
        development => "768m",
        virtual     => "768m"
      };
    }
    tomcat::manager { "admin": password => "admin" }
  }
}

class bizpublic
{
  include bizstatic

  bizstatic::site { "bizcard":
    server_name    => "www.bizcard.com",
    server_alias   => "bizcard.com",
    server_admin   => "webmaster@bizcard.com",
    #proxy_hosts  => [ "${ws_1_ip}:8080" ];
    proxy_hosts  => [ "${ws_1_ip}" ];
  }
}

node 'biz-p2-srv-1.corp.smartceg.com',
     'biz-d2-srv-1.corp.smartceg.com',
     'biz-d1-srv-1.corp.smartceg.com' inherits bizdefault
{
  #include bizpuppetmaster
  #include bizgateway
  include bizdatabase
  include bizappserver

  if $server_type != "virtual" {
    include firewall
    include psacct
  } else {
    include vmware::vm

    Nagios::Target::Monitor["$pm_1"] {
      root_volume => "/dev/mapper/VolGroup01-LogVol00"
    }
  }

  selinux::state { disabled: }

  Nagios::Service[check_hda1] {
    args => "check_sda1"
  }

  interface { eth0:
    bootproto => "static",
    address   => $srv_1_ip;
  }

  firewall::access { public:
    device  => "eth0",
    address => $srv_1_ip;
  }
  firewall::access { private:
    device  => "eth1",
    address => $srv_1_ip;
  }

  apache::mod_jk { node1:
    host    => "localhost",
    uris    => [ "/csr", "/csr/*" ];
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
    source  => "puppet:///modules/biz/canonical",
    ensure  => present,
    notify  => Exec[canonicaldb],
    require => Package[postfix];
  }

  cron { "stop all services":
    ensure  => present,
    command => "/usr/bin/ctl stop all > /dev/null",
    user    => "root",
    hour    => 4,
    minute  => 18;
  }
  cron { "restart services":
    ensure  => present,
    command => "/usr/bin/ctl start all > /dev/null",
    user    => "root",
    hour    => 4,
    minute  => 22;
  }

  Nagios::Target::Monitor["$pm_1"] {
      max_procs_warn => 250,
      max_procs_crit => 300
  }
}

node 'biz-p2-srv-2.corp.smartceg.com',
     'biz-d2-srv-2.corp.smartceg.com',
     'biz-d1-srv-2.corp.smartceg.com' inherits bizslave
{
  include bizfileserver
  include biztomcat

  case $server_type {
    "production": {
      include vmware::server
      include firewall
  
      ipforward { enabled: }
    
      iproute { external:
        device  => "eth1",
        routes => [ "default via $srv_1_ip" ];
      }
    
      iproute { internal:
        device  => "eth0",
        routes => [ "172.24.8.0/24 via 10.9.19.120",
                    "172.16.0.0/24 via 10.9.19.120" ];
      }
    
      interface { eth0:
        bootproto => "static",
        address   => $srv_2_ip;
      }
    
      firewall::access { public:
        device  => "eth0",
        address => $srv_2_ip;
      }
      firewall::access { private:
        device  => "eth0",
        address => $srv_2_ip;
      }
    }
    "development": {
      include vmware::server
      include firewall
  
      # ipforward { enabled: }
      # 
      # iproute { external:
      #   device  => "eth1",
      #   routes => [ "default via $srv_1_ip" ];
      # }
      # 
      # iproute { internal:
      #   device  => "eth0",
      #   routes => [ "172.24.8.0/24 via 10.9.19.120",
      #               "172.16.0.0/24 via 10.9.19.120" ];
      # }
      # 
      # interface { eth0:
      #   bootproto => "static",
      #   address   => $srv_2_ip;
      # }

      firewall::access { public:
        device  => "eth1",
        address => $srv_2_ip;
      }
      firewall::access { private:
        device  => "eth1",
        address => $srv_2_ip;
      }
    }
    "virtual": {
      include vmware::vm
  
      interface { eth0: }
    }
  }

  selinux::state { disabled: }

  Nagios::Service[check_hda1] {
    args => "check_sda1"
  }

  firewall::pre_tmpl { forward: module => "biz" }

  cron { "stop all services":
    ensure  => present,
    command => "/usr/bin/ctl stop all > /dev/null",
    user    => "root",
    hour    => 4,
    minute  => 15;
  }
  cron { "restart services":
    ensure  => present,
    command => "/usr/bin/ctl start all > /dev/null",
    user    => "root",
    hour    => 4,
    minute  => 30;
  }

  Nagios::Target::Monitor["$pm_1"] {
    max_procs_warn => 225,
    max_procs_crit => 260
  }

  include bizaux

  bizaux::billing_server             { "BillingServer":            serverid => 1 }
  bizaux::approval_server            { "ApprovalServer":           serverid => 2 }
  bizaux::order_closer               { "OrderCloser":              serverid => 6 }
  bizaux::receipt_process_server     { "ReceiptProcessServer":     serverid => 9 }

  if $server_type == "production" {
    # Only run the automated billing service in production use
    bizaux::payment_transaction_server { "PaymentTransactionServer": serverid => 0 }
  }
}

node 'biz-p2-pub-1.corp.smartceg.com',
     'biz-p1-ws-1.corp.smartceg.com',
     'biz-p1-ws-2.corp.smartceg.com', 'biz-p1-ws-2', 'biz-p1-ws-2.bizcard.com',
     'biz-d2-pub-1.corp.smartceg.com',
     'biz-d1-pub-1.corp.smartceg.com' inherits bizslave
{
  include bizpublic

  if $server_type == "production" {
    include firewall

    interface { eth1:
      bootproto => "static",
      address   => $internet_addr,
      net_mask  => $gateway_mask,
      gateway   => $gateway_addr;
    }

    iproute { internal:
      device  => "eth0",
      routes => [ "172.24.8.0/24 via 10.100.1.251",
                  "172.16.6.0/24 via 10.100.1.251" ];
    }

    firewall::access { public:
      device    => "eth1",
      address   => $internet_addr;
    }

  } else {
    if $server_type == "virtual" {
      include vmware::vm
    }
  }

  #selinux::state { enforcing: }
  selinux::state { permissive: }

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

  nfs::client::setup { "$net_domain":
    nobody_user  => "nobody",
    nobody_group => "nobody";
  }

  nfs::client::mount { "$doc_path":
    host  => "$fs_1",
    share => "$doc_path";
  }
}
