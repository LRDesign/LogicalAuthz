class LogicalAuthzGenerator < LogicalAuthz::Generator
  def manifest
    record do |manifest|
      manifest.dependency "logical_authz_models", [], options
      manifest.dependency "logical_authz_specs", [], options
      manifest.dependency "logical_authz_routes", [], options

      manifest.template "app/controllers/authz_controller.rb.erb", "app/controllers/authz_controller.rb"
      manifest.template "app/views/layouts/_explain_authz.html.haml", "app/views/layouts/_explain_authz.html.haml.erb"
      manifest.readme "README"
    end
  end
end
