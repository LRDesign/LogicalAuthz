ENV["RAILS_ENV"] ||= "test"

PROJECT_ROOT = File.expand_path("../..", __FILE__)
$LOAD_PATH << File.join(PROJECT_ROOT, "lib")

require 'rails/all'
Bundler.require

require 'spec_help/support/application'
require 'logical_authz'
require 'logical_authz/common'

class ApplicationController < ActionController::Base
  include LogicalAuthz::Application
end

class AuthzController < ApplicationController
end

Testing::Application.initialize!

require 'rails/test_help'
require 'rspec/rails'

class User < ActiveRecord::Base
end


Dir[Rails.root.join("spec_help/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.backtrace_clean_patterns << %r{gems/}
end

$db_seq_num = 0
def seq
  return $db_seq_num += 1
end
