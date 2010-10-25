require 'logical_authz/generator'

module LogicalAuthz
  class ControllerGenerator < LogicalAuthzGenerator
    source_paths << File::expand_path("../templates", __FILE__)

    def create_authz_controller
      template "app/controllers/authz_controller.rb"
    end

    def insert_authz_application
      inject_into_class "app/controllers/application_controller.rb", ApplicationController do
        "  include LogicalAuthz::Application\n"
      end
    end
  end
end
