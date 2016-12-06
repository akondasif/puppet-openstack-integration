class openstack_integration::panko {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'panko':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'panko@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'panko':
      notify  => Service['httpd'],
      require => Package['panko'],
    }
    Exec['update-ca-certificates'] ~> Service['httpd']
  }

  include ::panko

  class { '::panko::db':
    database_connection => 'mysql+pymysql://panko:panko@127.0.0.1/panko?charset=utf8',
  }

  class { '::panko::db::mysql':
    password => 'panko',
  }
  class { '::panko::keystone::auth':
    public_url   => "${::openstack_integration::config::base_url}:8779",
    internal_url => "${::openstack_integration::config::base_url}:8779",
    admin_url    => "${::openstack_integration::config::base_url}:8779",
    password     => 'a_big_secret',
  }
  class { '::panko::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::panko::api':
    sync_db      => true,
    enabled      => true,
    service_name => 'httpd',
  }
  include ::apache
  class { '::panko::wsgi::apache':
    bind_host => $::openstack_integration::config::ip_for_url,
    ssl       => $::openstack_integration::config::ssl,
    ssl_key   => "/etc/panko/ssl/private/${::fqdn}.pem",
    ssl_cert  => $::openstack_integration::params::cert_path,
    workers   => 2,
  }

}
