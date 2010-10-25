require 'logical_authz/generator'

module LogicalAuthz
  class ModelGenerator < LogicalAuthzGenerator
    include Rails::Generators::Migration

    class_option :user_class, :required => true
    class_option :permission_class, :default => "Permission"
    class_option :group_class, :default => "Group"
    class_option :admin_group, :default => "Administrators"

    no_tasks do
      def template_data
        @template_data ||= {
          :user_table => options[:user_class].tableize,
          :permission_table => options[:permission_class].tableize,
          :group_table => options[:group_class].tableize,
          :user_field => options[:user_class].underscore,
          :permission_field => options[:permission_class].underscore,
          :group_field => options[:group_class].underscore,
        }
      end

      def user_class; options[:user_class]; end
      def permission_class; options[:permission_class]; end
      def group_class; options[:group_class]; end
      def admin_group; options[:admin_group]; end

      def user_table; template_data[:user_table]; end
      def permission_table; template_data[:permission_table]; end
      def group_table; template_data[:group_table]; end

      def user_field; template_data[:user_field]; end
      def permission_field; template_data[:permission_field]; end
      def group_field; template_data[:group_field]; end
    end

    #Tragically, this is locked to AR right now
    def self.next_migration_number(dirname) #:nodoc:
      next_migration_number = current_migration_number(dirname) + 1
      if ActiveRecord::Base.timestamped_migrations
        [Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % next_migration_number].max
      else
        "%.3d" % next_migration_number
      end
    end

    source_paths << File::expand_path("../templates", __FILE__)

    def generate_group_model
      invoke "logical_authz:group_model"
    end

    def generate_permissions_model
      invoke "logical_authz:permission_model"
    end

    def create_seeds
      template "db/seeds_logical_authz.rb"
      append_file "db/seeds.rb", "require 'db/seeds_logical_authz'"
    end

    def create_initializer
      template "config/initializers/logical_authz.rb"
    end
  end

  class GroupModelGenerator < ModelGenerator
    def create_model
      template "app/models/group.rb", "app/models/#{group_field}.rb"
    end

    def inject_habtm_groups
      inject_into_class "app/models/#{user_field}.rb", user_class, "  has_and_belongs_to_many :#{group_table}\n"
    end

    def create_migration
      dest_file = "db/migrate/create_#{group_field}.rb"
      begin
        migration_template "migrations/create_groups.rb", dest_file
      rescue Rails::Generators::Error
        say_status :exist, dest_file, :blue
      end

      dest_file = "db/migrate/create_#{user_table}_#{group_table}.rb"
      begin
        migration_template "migrations/create_users_groups.rb", dest_file
      rescue Rails::Generators::Error
        say_status :exist, dest_file, :blue
      end
    end
  end

  class PermissionModelGenerator < ModelGenerator
    def create_model
      template "app/models/permission.rb", "app/models/#{permission_field}.rb"
    end

    def create_migration
      dest_file = "db/migrate/create_#{permission_field}.rb"
      migration_template "migrations/create_permissions.rb", dest_file
    rescue Rails::Generators::Error
      say_status :exist, dest_file, :blue 
    end
  end

  #manifest.class_collisions options[:group_class], 
  #options[:permission_class]
end
