module LogicalAuthz
  #These settings are all available in your configuration as:
  #config.logical_authz.{setting}
  class Configuration
    class << self
      #XXX is this redundant and confusing now?
      def policy_helper(name, &block)
        require 'logical_authz/access_policy/dsl'
        AccessPolicy::Builder.register_policy_helper(name, &block)
      end

      def unauthorized_roles
        return @unauthorized_roles unless @unauthorized_roles.nil?
        roles = unauthorized_role_names.map do |name|
          Role.find_by_name(name)
        end
        if Rails.configuration.cache_classes
          @unauthorized_roles = roles 
        end
        return roles
      end

      def clear_unauthorized_roles
        @unauthorized_roles = nil
      end

      def unauthorized_role_names=(array)
        @unauthorized_role_names = array
      end

      def unauthorized_role_names
        @unauthorized_role_names ||= []
      end

      def permission_model=(klass)
        @perm_model = klass
      end

      def permission_model
        @perm_model || ::Permission rescue nil
      end

      def divert_urls
        @divert_urls ||= ["/"] 
      end

      def divert_urls=(list)
        @divert_urls = list
      end

      def admin_role?(role)
        return (role.name == "member" and 
                Group.find(role.role_range_id).name == "Administrators")
      end

      def admin_role(&block)
        define_method :admin_role?, &block
      end

      def raise_policy_exceptions!
        @raise_policy_exceptions = true
      end

      def raise_policy_exceptions?
        defined? @raise_policy_exceptions and @raise_policy_exceptions 
      end

      def debug!
        @debug = true
      end

      def no_debug
        @debug = false
      end

      def debugging?
        defined? @debug and @debug
      end
    end
  end
end
