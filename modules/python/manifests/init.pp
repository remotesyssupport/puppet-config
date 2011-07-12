class python
{
  $packages = [python, python-setuptools]

  package { $packages: ensure => installed }

  $var_setuptools = "/var/lib/setuptools" 

  file { $var_setuptools:
    ensure => directory,
    owner  => "root",
    group  => "root",
    mode   => 0755;
  }

  exec { "update setuptools":
    timeout   => 900,
    user      => "root",
    cwd       => "$var_setuptools",
    command   => "/usr/bin/easy_install -U setuptools && touch /usr/bin/.setuptools_updated",
    creates   => "/usr/bin/.setuptools_updated",
    require   => Package[python-setuptools];
  }
}

define pymod ()
{
  $var_setuptools = "/var/lib/setuptools" 
  $pymod_record   = "$var_setuptools/$title.files"

  exec { "easy_install $title":
    timeout   => 900,
    cwd       => "$var_setuptools",
    creates   => "$pymod_record",
    command   => "/usr/bin/easy_install --record $pymod_record $title",
    user      => "root",
    logoutput => on_failure,
    require   => Exec["update setuptools"];
  }
}
