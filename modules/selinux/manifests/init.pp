class selinux
{
  package { audit: ensure => installed }

  file { "/etc/selinux/local":
    owner  => "root",
    group  => "root",
    mode   => 0700,
    type   => directory,
    ensure => directory;
  }

  file { "/etc/selinux/local/update-policy.sh":
    owner   => "root",
    group   => "root",
    mode    => 0755,
    ensure  => present,
    source  => "puppet:///modules/selinux/update-policy.sh",
    require => File["/etc/selinux/local"];
  }

  define state () {
    case $title {
      enforcing: {
        exec { "enable selinux on $hostname":
          user    => "root",
          command => "/usr/sbin/setenforce 1",
          unless  => "/usr/sbin/sestatus | /bin/egrep -q '(Current mode:.*enforcing)'";
        }
      }
      permissive: {
        exec { "disable selinux on $hostname":
          user    => "root",
          command => "/usr/sbin/setenforce 0",
          unless  => "/usr/sbin/sestatus | /bin/egrep -q '(Current mode:.*permissive|SELinux.*disabled)'";
        }
      }
    }

    file { "/etc/selinux/config":
      owner   => "root",
      group   => "root",
      mode    => 0644,
      ensure  => present,
      content => template("selinux/config.erb");
    }
  }

  define policy ($module = false) {
    include selinux

    file { "/etc/selinux/local/$title.te":
      owner   => "root",
      group   => "root",
      mode    => 0600,
      ensure  => present,
      source => $module ? {
        false   => "puppet:///modules/$title/$title.te",
        default => "puppet:///modules/$module/$title.te"
      },
      require => File["/etc/selinux/local/update-policy.sh"];
    }

    exec { "update-$title":
      user        => "root",
      cwd         => "/etc/selinux/local",
      command     => "/bin/sh update-policy.sh $title",
      refreshonly => true,
      subscribe   => File["/etc/selinux/local/$title.te"];
    }
  }
}
