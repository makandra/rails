print "Using native MySQL\n"
require_dependency 'models/course'
require 'logger'

ActiveRecord::Base.logger = Logger.new("debug.log")

# GRANT ALL PRIVILEGES ON activerecord_unittest.* to 'rails'@'localhost';
# GRANT ALL PRIVILEGES ON activerecord_unittest2.* to 'rails'@'localhost';

# Rails LTS: OpenSSL 3 rejects the TLS our old MySQL service containers offer,
# and there is nothing to protect on a throwaway test database. Older mysql2
# versions ignore the option.
ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'mysql2',
    :username => ENV['MYSQL_USER'],
    :encoding => 'utf8',
    :database => 'activerecord_unittest',
    :host     => ENV['MYSQL_HOST'],
    :ssl_mode => 'disabled',
  },
  'arunit2' => {
    :adapter  => 'mysql2',
    :username => ENV['MYSQL_USER'],
    :database => 'activerecord_unittest2',
    :host     => ENV['MYSQL_HOST'],
    :ssl_mode => 'disabled',
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'
