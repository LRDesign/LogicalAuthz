$: << File::expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
$: << File::expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require 'spec/spec_helper'

require 'logical_authz'
require 'spec/support/mock_auth'
require 'logical_authz/spec_helper'


