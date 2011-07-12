class ruby
{
  case $operatingsystem
  {
    centos: {
      $pkg_rubygems  = "ruby-enterprise-rubygems"
      $ruby_bin_path = "/usr/local/bin"

      $packages = [ "ruby-enterprise", $pkg_rubygems ]

      package { $packages: ensure => latest }
    }

    darwin: {
      $pkg_rubygems  = "rb-rubygems"
      $ruby_bin_path = "/opt/local/bin"

      $packages = [ "ruby", $pkg_rubygems ]

      package { $packages:
        ensure   => latest,
        provider => darwinport;
      }

      rubygem { "shadow": }
    }
  }

  define rubygem() {
    exec { "install $title":
      timeout => 600,
      command => "/usr/local/bin/gem install ---remote $title",
      unless  => "/usr/local/bin/gem list --local $title | /bin/grep -q $title";
    }
  }
}

class ruby::rails inherits ruby
{
  rubygem { rails: }
}
