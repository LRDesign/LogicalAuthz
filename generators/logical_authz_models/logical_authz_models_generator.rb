class LogicalAuthzModelsGenerator < Rails::Generator::Base
  def add_options!(opti)
    opti.on("-u", "--user UserClass"){|val| options[:user_class] = val}
    opti.on("-p", "--permission PermissionClass"){|val| options[:permission_class] = val}
    opti.on("-g", "--group GroupClass"){|val| options[:group_class] = val}
    opti.on("-A", "--admin AdminGroupName"){|val| options[:admin_group] = val}
  end

  default_options(:permission_class => "Permission", 
                  :group_class => "Group",
                  :admin_group => "Administration")

  def manifest 
    raise "User class name (--user) is required!" unless options[:user_class]
    template_data = {
      :user_class => options[:user_class],
      :permission_class => options[:permission_class],
      :group_class => options[:group_class],
      :user_table => options[:user_class].tableize,
      :permission_table => options[:permission_class].tableize,
      :group_table => options[:group_class].tableize,
      :user_field => options[:user_class].underscore,
      :permission_field => options[:permission_class].underscore,
      :group_field => options[:group_class].underscore,
      :admin_group => options[:admin_group]
    }

    record do |manifest|
      manifest.class_collisions options[:group_class], options[:permission_class]
      manifest.template "app/models/group.rb.erb", "app/models/group.rb", :assigns => template_data
      manifest.template "app/models/permission.rb.erb", "app/models/permission.rb", :assigns => template_data
      manifest.template "config/initializers/logical_authz.rb.erb", "config/initializers/logical_authz.rb", :assigns => template_data
      manifest.template "db/seeds_logical_authz.rb.erb", "db/seeds_logical_authz.rb", :assigns => template_data
      manifest.migration_template "migrations/create_groups.rb.erb", "db/migrate", :migration_file_name => "setup_logical_authz", :assigns => template_data
      manifest.migration_template "migrations/create_permissions.rb.erb", "db/migrate", :migration_file_name => "setup_logical_authz", :assigns => template_data
      manifest.migration_template "migrations/create_users_groups.rb.erb", "db/migrate", :migration_file_name => "setup_logical_authz", :assigns => template_data
    end
  end
end
