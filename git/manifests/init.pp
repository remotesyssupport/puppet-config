class git
{
  $packages = [ git ]

  case $operatingsystem {
    centos:  {
      package { $packages: ensure => latest }
    }

    darwin: {
      package { git-core: ensure => latest }
    }

    default: {
      package { $packages: ensure => latest }
    }
  }
}
