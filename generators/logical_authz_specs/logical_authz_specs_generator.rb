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
        templ.template "spec/factories/permissions.rb.erb", "spec/factories/logical_authz_#{template_data[:permission_table]}.rb"
        templ.template "spec/support/logical_authz.rb.erb", "spec/support/logical_authz.rb"
        templ.template "spec/support/mock_auth.rb.erb", "spec/support/mock_auth.rb"
        templ.template "spec/controllers/permissions_controller_spec.rb.erb", "spec/controllers/permissions_controller_spec.rb"
        templ.template "spec/controllers/groups_controller_spec.rb.erb", "spec/controllers/groups_controller_spec.rb"
        templ.template "spec/controllers/groups_users_controller_spec.rb.erb", "spec/controllers/groups_users_controller_spec.rb"
        templ.template "spec/helpers/logical_authz_helper_spec.rb.erb", "spec/helpers/logical_authz_helper_spec.rb"
      end
    end
  end
end
