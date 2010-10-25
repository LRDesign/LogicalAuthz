require 'logical_authz'
require 'rails'

module LogicalAuthz
  class Engine < Rails::Engine
    generators do
      require 'logical_authz/generator'
      require 'logical_authz/generators/models/generator'
      require 'logical_authz/generators/routes/generator'
      require 'logical_authz/generators/specs/generator'
    end
  end
end
