module LogicalAuthz
  class SpecsGenerator < LogicalAuthzGenerator
    source_paths << File::expand_path("../templates", __FILE__)

    class_option :user_class, :required => true
    class_option :permission_class, :default => "Permission"
    class_option :group_class, :default => "Group"

    no_tasks do
      def template_data
        @template_data ||= {
          :user_table => options[:user_class].tableize,
          :permission_table => options[:permission_class].tableize,
          :group_table => options[:group_class].tableize,
        }
      end

      def user_class; options[:user_class]; end
      def permission_class; options[:permission_class]; end
      def group_class; options[:group_class]; end
      def admin_group; options[:admin_group]; end

      def user_table; template_data[:user_table]; end
      def permissions_table; template_data[:permissions_table]; end
      def group_table; template_data[:group_table]; end
    end

    def create_factories
      empty_directory "spec/factories"

      template "spec/factories/az_accounts.rb", "spec/factories/logical_authz_#{template_data[:user_table]}.rb"
      template "spec/factories/az_groups.rb", "spec/factories/logical_authz_#{template_data[:group_table]}.rb"
      template "spec/factories/permissions.rb", "spec/factories/logical_authz_#{template_data[:permission_table]}.rb"
    end

    def create_helper_spec
      template "spec/helpers/logical_authz_helper_spec.rb", "spec/helpers/logical_authz_helper_spec.rb"
    end

=begin
    def manifest
      record do |manifest|
        manifest.directory "spec/factories"
        manifest.directory "spec/support"
        manifest.directory "spec/controllers"
        manifest.directory "spec/helpers"

        manifest.with_options :assigns => template_data do |templ|
          templ.template "spec/support/logical_authz.rb", "spec/support/logical_authz.rb"
          templ.template "spec/support/mock_auth.rb", "spec/support/mock_auth.rb"
          templ.template "spec/controllers/permissions_controller_spec.rb", "spec/controllers/permissions_controller_spec.rb"
          templ.template "spec/controllers/groups_controller_spec.rb", "spec/controllers/groups_controller_spec.rb"
          templ.template "spec/controllers/groups_users_controller_spec.rb", "spec/controllers/groups_users_controller_spec.rb"
        end
      end
    end
=end
  end
end
