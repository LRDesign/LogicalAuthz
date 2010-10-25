require 'rails/generators'
require 'rails/generators/base'
module LogicalAuthz
  class LogicalAuthzGenerator < Rails::Generators::Base
    def models
      invoke("logical_authz:model")
    end

    def routes
      invoke("logical_authz:routes")
    end

    def specs
      invoke("logical_authz:specs")
    end

    def controllers
      invoke("logical_authz:controllers")
    end

  end
end
