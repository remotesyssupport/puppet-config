import "base"

node cegdefs
{
  $administrator = "root@localhost"
  $net_domain    = "corp.smartceg.com"

  $net_cluster   = "172.24.8"
  $net_mask      = "255.255.255.0"
  $net_range     = "${net_cluster}.0/24"

  $gw_1          = "genie.${net_domain}"            # Internet gateway
  $pm_1          = "proton.${net_domain}"           # Puppet master
  $fs_1          = "proton.${net_domain}"           # Puppet master
  $vc_1          = "quark.${net_domain}"           # Puppet master
}

node cegdefault inherits cegdefs
{
  include base
  include puppet::client
  include centos::admin
  include ntp
  include sshd
  include rsyslog
  include nagios::target

  mailalias { "root":  recipient => "admin" }
  mailalias { "admin": recipient => "$administrator" }

  tcpwrapper { nrpe:  allow => "127.0.0.1, $net_cluster."; }
  tcpwrapper { "ALL": allow => "127.0.0.1, $net_cluster."; }

  $plugin_dir = $architecture ? {
    "x86_64" => "/usr/lib64/nagios/plugins",
    "i386"   => "/usr/lib/nagios/plugins"
  }
  nagios::target::monitor { "$pm_1": }
  nagios::target::command { "check_dig_server":
    command => "$plugin_dir/check_dig -H $gw_1 -l $fqdn";
  }
}

node cegslave inherits cegdefault
{
  include rsyslog

  rsyslog::client { "$pm_1": }
}

node 'proton.corp.smartceg.com' inherits cegdefault
{
  include centos::devel
  include puppet::server::stored_configs
  include rsyslog
  include samba::server
  #include vmware::server
  include nagios::monitor
  include firewall
  include postfix

  teamcity::agent { "http://portal.corp.smartceg.com/teamcity": }

  interface { eth0: }

  firewall::access { private: device => "eth0" }
  firewall::access { public:  device => "eth0" }

  host { "localhost.localdomain":
    ip     => "127.0.0.1",
    alias  => [ "localhost", "puppet" ],
    ensure => present;
  }

  nagios::service { check_md2:
    command => "check_nrpe",
    args    => "check_md2";
  }

  # This resource exists solely to quiet warnings from Nagios about the HTTP
  # server being unresponsive.
  file { "/var/www/html/index.html":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    content => "\n",
    ensure  => present,
    require => Package[httpd];
  }

  rsyslog::server { "${net_range}": }

  postgres::access { "${net_range}": method => "md5" }

  # jww (2010-02-28): don't need to export this right now
  #nfs::server::exports { "/srv":
  #  domain_name   => "$net_domain",
  #  nobody_user   => "nobody",
  #  nobody_group  => "nobody",
  #  shares        => [ "data" ],
  #  share_access  => "${net_range}",
  #  # the user and group id 99=nobody
  #  share_options => "rw,sync,all_squash,anonuid=99,anongid=99";
  #}

  cron { "backup quark":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete --exclude=/carbon/ quark:/srv/ /srv/backup/quark/",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }

  cron { "backup abc-p1-srv-1":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete --exclude='/db2/*_P[0-9]/' abc-p1-srv-1:/srv/ /srv/backup/abc-p1-srv-1/",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }

  cron { "backup abc-p1-srv-2":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete --exclude=/documents/session/ --exclude=/documents/temp/ abc-p1-srv-2:/mnt/data/ /srv/backup/abc-p1-srv-2/data/",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }

  cron { "backup biz-p2-srv-1":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete --exclude='/db2/*_P[0-9]/' 10.100.1.201:/srv/ /srv/backup/biz-p2-srv-1/",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }

  cron { "backup biz-p2-srv-2":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete --exclude=/documents/session/ --exclude=/documents/temp/ 10.100.1.202:/mnt/data/ /srv/backup/biz-p2-srv-2/data/",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }

  cron { "backup sahara":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete --exclude=/www/ sahara:/srv/ /srv/backup/sahara/ 2>&1 | /bin/egrep -v '(reverse mapping checking|does not map back)'",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }

  cron { "backup sahara www":
    ensure  => present,
    command => "/usr/bin/rsync -az --delete sahara:/var/www/ /srv/backup/sahara/www/ 2>&1 | /bin/egrep -v '(reverse mapping checking|does not map back)'",
    user    => "root",
    hour    => 8,
    minute  => 0;
  }
}

node 'quark.corp.smartceg.com' inherits cegslave
{
  include firewall
  include postfix
  include gitolite
  include postgres

  interface { eth0: }

  firewall::access { private: device => "eth0" }
  firewall::access { public:  device => "eth0" }

  nagios::service { check_root:
    command => "check_nrpe",
    args    => "check_root";
  }

  postgres::database { "wiki":
    user     => "wiki",
    password => "wiki";
  }
  postgres::database { "bugzilla":
    user     => "bugzilla",
    password => "bugzilla";
  }
  postgres::database { "teamcity":
    user     => "teamcity",
    password => "teamcity";
  }
  postgres::database { "archiva":
    user     => "archiva",
    password => "archiva";
  }
  postgres::database { "archiva_users":
    user     => "archivausers",
    password => "archivausers";
  }

  postgres::access { "${net_range}": method => "md5" }

  # jww (2010-02-28): don't need to mount this right now
  #nfs::client::mount { "/mnt/data":
  #  domain_name  => "$net_domain",
  #  nobody_user  => "git",
  #  nobody_group => "git",
  #  host         => "$fs_1",
  #  share        => "/srv/data";
  #}

  nfs::server::exports { "/srv":
    domain_name   => "$net_domain",
    nobody_user   => "nobody",
    nobody_group  => "nobody",
    shares        => [ "wiki", "teamcity", "archiva" ],
    share_access  => "${net_range}",
    # the user and group id 99=nobody
    share_options => "rw,sync,all_squash,anonuid=99,anongid=99";
  }

  cron { "backup postgres for quark":
    ensure  => present,
    command => "su - postgres -c /usr/bin/pg_dumpall > /srv/postgres.sql",
    user    => "root",
    hour    => 4,
    minute  => 0;
  }
}

node 'portal.corp.smartceg.com' inherits cegslave
{
  include firewall
  include postfix
  include jboss
  include confluence
  include archiva
  include teamcity
  include bugzilla
  include apache::secure

  interface { eth0: }

  firewall::access { private: device => "eth0" }
  firewall::access { public:  device => "eth0" }

  nagios::service { check_root:
    command => "check_nrpe",
    args    => "check_root";
  }

  bugzilla::database { "$vc_1": }

  jboss::server { $fqdn:
    serverid   => 1,
    options    => "-Dsun.rmi.dgc.client.gcInterval=1800000 -Dsun.rmi.dgc.server.gcInterval=1800000 -XX:+UseParallelGC -XX:ParallelGCThreads=4 -XX:MaxPermSize=128m",
    min_memory => "1280m",
    max_memory => "1280m";
  }

  jboss::logger { "$pm_1": }

  jboss::datasource { "wiki-ds":
    name     => "WikiDS",
    url      => "jdbc:postgresql://${vc_1}:5432/wiki?ssl=true&amp;sslfactory=org.postgresql.ssl.NonValidatingFactory",
    driver   => "org.postgresql.Driver",
    username => "wiki",
    password => "wiki",
    mapping  => "PostgreSQL 8.0";
  }

  confluence::wiki { "/srv/wiki": }

  jboss::datasource { "teamcity-ds":
    name     => "TeamCityDS",
    url      => "jdbc:postgresql://${vc_1}:5432/teamcity?ssl=true&amp;sslfactory=org.postgresql.ssl.NonValidatingFactory",
    driver   => "org.postgresql.Driver",
    username => "teamcity",
    password => "teamcity",
    mapping  => "PostgreSQL 8.0";
  }

  jboss::datasource { "archiva-ds":
    name     => "ArchivaDS",
    url      => "jdbc:postgresql://${vc_1}:5432/archiva?ssl=true&amp;sslfactory=org.postgresql.ssl.NonValidatingFactory",
    driver   => "org.postgresql.Driver",
    username => "archiva",
    password => "archiva",
    mapping  => "PostgreSQL 8.0";
  }

  jboss::datasource { "archiva-users-ds":
    name     => "ArchivaUsersDS",
    url      => "jdbc:postgresql://${vc_1}:5432/archiva_users?ssl=true&amp;sslfactory=org.postgresql.ssl.NonValidatingFactory",
    driver   => "org.postgresql.Driver",
    username => "archivausers",
    password => "archivausers",
    mapping  => "PostgreSQL 8.0";
  }

  nfs::client::setup { "$net_domain":
    nobody_user  => "jboss",
    nobody_group => "jboss",
    require      => Package[jboss];
  }

  nfs::client::mount { "/mnt/wiki":
    host  => "$vc_1",
    share => "/srv/wiki";
  }
  nfs::client::mount { "/mnt/archiva":
    host  => "$vc_1",
    share => "/srv/archiva";
  }

  file { "/etc/httpd/conf.d/portal.conf":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/ceg/portal.conf",
    notify  => Service[httpd],
    require => Package[httpd];
  }
}

node 'sahara.corp.smartceg.com' inherits cegslave
{
  include firewall
  include postfix
  include apache::secure
  include mysql
  include imagemagick
  include psacct

  interface { eth0: }
  interface { eth1:
    bootproto => "static",
    address   => "67.137.106.135",
    net_mask  => "255.255.255.0",
    gateway   => "67.137.106.129";
  }

  firewall::access { private: device => "eth0" }
  firewall::access { public:  device => "eth1" }

  firewall::rule { sahara:
    module => "ceg";
  }

  #iproute { vpn:
  #  device  => "eth0",
  #  address => "172.16.0.0/24",
  #  gateway => "172.24.8.45";
  #}

  nagios::service { check_root:
    command => "check_nrpe",
    args    => "check_root";
  }

  yumrepo { remi:
    descr          => 'Les RPM de remi pour Enterprise Linux 5 - $basearch',
    baseurl        => "http://rpms.famillecollet.com/el5.\$basearch/\n http://iut-info.univ-reims.fr/remirpms/el5.\$basearch/",
    enabled        => 1,
    gpgcheck       => 1,
    priority       => 2,
    gpgkey         => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-remi',
    failovermethod => 'priority';
  }

  $packages = [ "php", "php-gd", "php-magickwand", "ghostscript",
                "remi-release", "phpMyAdmin", "php-ZendFramework",
                "php-mysql", "php-ZendFramework-Db-Adapter-Mysqli",
                "php-pecl-imagick" ]

  package { $packages:
    ensure => installed,
    require => Yumrepo[remi];
  }

  group { anil: ensure => present }
  group { webmaster: ensure => present }

  user { anil:
    groups  => [ anil, webmaster ],
    home    => "/home/anil",
    shell   => "/bin/bash",
    ensure  => present,
    require => [ Group[anil], Group[webmaster] ];
  }

  file { "/var/www":
    owner   => "root",
    group   => "webmaster",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "httpd_sys_content_t",
    type    => directory,
    recurse => true,
    require => Package[httpd];
  }

  file { "/etc/httpd/conf.d":
    owner   => "root",
    group   => "webmaster",
    seluser => "system_u",
    selrole => "object_r",
    seltype => "httpd_config_t",
    type    => directory,
    recurse => true,
    require => Package[httpd];
  }

  file { "/usr/share/phpMyAdmin/config.inc.php":
    owner   => "root",
    group   => "root",
    mode    => 0644,
    ensure  => present,
    source  => "puppet:///modules/ceg/config.inc.php",
    require => Package[phpMyAdmin];
  }

  file { "/etc/php.ini":
    owner   => "root",
    group   => "webmaster",
    mode    => 0664,
    ensure  => present,
    require => Package[php];
  }

  cron { "backup mysql for sahara":
    ensure  => present,
    command => "mysqldump --user=root --password=root --all-databases > /srv/mysql.sql",
    user    => "root",
    hour    => 4,
    minute  => 0;
  }
}
