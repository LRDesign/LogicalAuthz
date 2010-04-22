class LogicalAuthzSpecsGenerator < LogicalAuthz::Generator
  default_options(:permission_class => "Permission", 
                  :group_class => "Group",
                  :admin_group => "Administration")

  def manifest
    record do |manifest|
      manifest.directory "spec/factories"
      manifest.directory "spec/support"
      manifest.directory "spec/controllers"
      manifest.directory "spec/helpers"

      manifest.with_options :assigns => template_data do |templ|
        templ.template "spec/factories/az_accounts.rb.erb", "spec/factories/logical_authz_#{template_data[:user_table]}.rb"
        templ.template "spec/factories/az_groups.rb.erb", "spec/factories/logical_authz_#{template_data[:group_table]}.rb"
        templ.template "spec/support/spec_helper.rb.erb", "spec/support/spec_helper.rb"
        templ.template "spec/support/mock_auth.rb.erb", "spec/support/mock_auth.rb"
        templ.template "spec/controllers/permissions_controller_spec.rb.erb"
        templ.template "spec/controllers/groups_controller_spec.rb.erb"
        templ.template "spec/controllers/groups_users_controller_spec.rb.erb"
        templ.template "spec/helpers/logical_authz_helper_spec.rb.erb"
      end
    end
  end
end
