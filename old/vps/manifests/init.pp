import "base"

class vps
{
  # jww (2009-05-02): Need to break these out into their own modules
  firewall::rule { vps: }
}

node 'vps.newartisans.com' inherits default
{
  interface { eth0:
    address => $environment ? {
      production => "208.70.150.153"
    }
  }
  interface { tun0:
    address => "10.8.0.1";
  }

  firewall::access { public:
    device  => "eth0",
    address => $ipaddress_eth0;
  }
  firewall::access { private:
    device  => "tun0",
    address => "10.8.0.1";
  }

  include openvpn

  include puppet::server::stored_configs
  include rsyslog::server

  include apache::secure
  include imagemagick
  include postfix
  include vsftpd

  include bittorrent::tracker

  include nagios::target
  include nagios::monitor

  #include nagios::ndoutils

  #include cyrusimapd
  #include gallery
  #include keys (/etc/pki)
  #include logwatch
  #include movabletype
  #include named
}
