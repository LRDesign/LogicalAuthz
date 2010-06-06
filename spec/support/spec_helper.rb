$: << File::expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
$: << File::expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require 'spec/spec_helper'

require 'logical_authz'
class AuthzController < ActionController::Base
  include LogicalAuthz::Application
end

require 'spec/support/mock_auth'
require 'logical_authz/spec_helper'


