require 'rails'
require 'logical_authz/configuration'

module LogicalAuthz
  class Engine < Rails::Engine
    generators do
      require 'logical_authz/generator'
      require 'logical_authz/generators/models/generator'
      require 'logical_authz/generators/routes/generator'
      require 'logical_authz/generators/specs/generator'
      require 'logical_authz/generators/controllers/generator'
    end

    config.eager_load_paths.unshift 'app/helpers'

    config.logical_authz = Configuration

    initializer :require_common do
      require 'logical_authz/common'
    end
  end
end
