module LogicalAuthz
  class ControllerGenerator
    source_path << File::expand_path("../templates", __FILE__)

    def create_authz_controller
      template "app/controllers/authz_controller.rb"
    end
  end
end
