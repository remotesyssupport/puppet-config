class bugzilla
{
  include apache::secure

  $packages = [ bugzilla, "perl-DBD-Pg" ]

  package { $packages: ensure => installed }

  define database($driver = "Pg", $database = "bugzilla",
                  $username = "bugzilla", $password = "bugzilla") {
    file { "/etc/bugzilla/localconfig":
      owner   => "root",
      group   => "apache",
      mode    => 0640,
      ensure  => present,
      content => template("bugzilla/localconfig.erb");
    }
  }
}
