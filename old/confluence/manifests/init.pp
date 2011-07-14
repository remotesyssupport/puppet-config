class confluence
{
  include jboss

  package { confluence: ensure => latest }

  define wiki() {
    file { "/usr/jboss/server/default/deploy/confluence-2.10.ear/atlassian-confluence.war/WEB-INF/classes/confluence-init.properties":
      owner   => "jboss",
      group   => "jboss",
      mode    => 0644,
      ensure  => present,
      content => template("confluence/confluence-init.properties.erb"),
      require => Package[confluence];
    }
  }
}
