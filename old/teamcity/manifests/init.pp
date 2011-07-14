class teamcity
{
  include jboss

  package { teamcity: ensure => installed }

  package { git: ensure => latest }
}

define teamcity::agent()
{
  include java
}
