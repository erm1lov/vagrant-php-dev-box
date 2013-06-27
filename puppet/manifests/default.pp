# Basic Puppet manifest

Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

class system-update {

    file { "/etc/apt/sources.list.d/dotdeb.list":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/apt/dotdeb.list",
    }

    exec { 'dotdeb-apt-key':
        cwd     => '/tmp',
        command => "wget http://www.dotdeb.org/dotdeb.gpg -O dotdeb.gpg &&
                    cat dotdeb.gpg | apt-key add -",
        unless  => 'apt-key list | grep dotdeb',
        require => File['/etc/apt/sources.list.d/dotdeb.list'],
        notify  => Exec['apt_update'],
    }

  exec { 'apt-get update':
    command => 'apt-get update',
  }

  $sysPackages = [ "build-essential" ]
  package { $sysPackages:
    ensure => "installed",
    require => Exec['apt-get update'],
  }
}

class nginx-setup {

  include nginx

  file { "/etc/nginx/sites-available/flatsy":
    owner  => root,
    group  => root,
    mode   => 664,
    source => "/vagrant/conf/nginx/default",
    require => Package["nginx"],
    notify => Service["nginx"],
  }

  file { "/etc/nginx/sites-enabled/default":
    owner  => root,
    ensure => link,
    target => "/etc/nginx/sites-available/flatsy",
    require => Package["nginx"],
    notify => Service["nginx"],
  }
}

class development {

  $devPackages = [ "curl", "git", "npm", "capistrano", "rubygems", "libaugeas-ruby" ]
  package { $devPackages:
    ensure => "installed",
    require => Exec['apt-get update'],
  }

  exec { 'install capifony using RubyGems':
    command => 'gem install capifony',
    require => Package["rubygems"],
  }

  exec { 'install capistrano_rsync_with_remote_cache using RubyGems':
    command => 'gem install capistrano_rsync_with_remote_cache',
    require => Package["capistrano"],
  }
}

class flatsy-standard {

  exec { 'git clone flatsy standard':
    command => 'git clone git@bitbucket.org:space1nvader/flatsea.git /vagrant/www/flatsy',
    creates => "/vagrant/www/flatsy"
  }

}

class devbox_php_fpm {

    php::module { [
        'curl', 'gd', 'mcrypt', 'memcached', 'mysql',
        'tidy', 'xhprof', 'imap',
        ]:
        notify => Class['php::fpm::service'],
    }

    php::module { [ 'memcache', 'apc', ]:
        notify => Class['php::fpm::service'],
        source  => '/etc/php5/conf.d/',
    }

    php::module { [ 'xdebug', ]:
        notify  => Class['php::fpm::service'],
        source  => '/etc/php5/conf.d/',
    }

    php::module { [ 'suhosin', ]:
        notify  => Class['php::fpm::service'],
        source  => '/vagrant/conf/php/',
    }

    exec { 'pecl-mongo-install':
        command => 'pecl install mongo',
        unless => "pecl info mongo",
        notify => Class['php::fpm::service'],
        require => Package['php-pear'],
    }

    exec { 'pecl-xhprof-install':
        command => 'pecl install xhprof-0.9.2',
        unless => "pecl info xhprof",
        notify => Class['php::fpm::service'],
        require => Package['php-pear'],
    }

    php::conf { [ 'mysqli', 'pdo', 'pdo_mysql', ]:
        require => Package['php-mysql'],
        notify  => Class['php::fpm::service'],
    }

    file { "/etc/php5/conf.d/custom.ini":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/php/custom.ini",
        notify => Class['php::fpm::service'],
    }

    file { "/etc/php5/fpm/pool.d/www.conf":
        owner  => root,
        group  => root,
        mode   => 664,
        source => "/vagrant/conf/php/php-fpm/www.conf",
        notify => Class['php::fpm::service'],
    }
}

class { 'apt':
  always_apt_update    => true
}

Exec["apt-get update"] -> Package <| |>

include system-update

include php::fpm
include devbox_php_fpm

include nginx-setup
include mysql

class {'mongodb':
  enable_10gen => true,
}

include phpqatools
include development
include flatsy-standard


