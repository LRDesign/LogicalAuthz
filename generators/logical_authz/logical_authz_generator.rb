class LogicalAuthzGenerator < LogicalAuthz::Generator
  def manifest
    record do |manifest|
      manifest.dependency "logical_authz_models", [], options
      manifest.dependency "logical_authz_specs", [], options
      manifest.dependency "logical_authz_routes", [], options
    end
  end
end
