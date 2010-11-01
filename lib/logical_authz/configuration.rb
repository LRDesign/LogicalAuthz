module LogicalAuthz
  #These settings are all available in your configuration as:
  #config.logical_authz.{setting}
  class Configuration
    class << self
      def policy_helper(name, &block)
        require 'logical_authz/access_control'
        AccessControl::Builder.define_method(name, &block)
      end

      def unauthorized_groups
        return @unauthorized_groups unless @unauthorized_groups.nil?
        groups = unauthorized_group_names.map do |name|
          Group.find_by_name(name)
        end
        if Rails.configuration.cache_classes
          @unauthorized_groups = groups 
        end
        return groups
      end

      def clear_unauthorized_groups
        @unauthorized_groups = nil
      end

      def unauthorized_group_names=(array)
        @unauthorized_group_names = array
      end

      def unauthorized_group_names
        @unauthorized_group_names ||= []
      end

      def permission_model=(klass)
        @perm_model = klass
      end

      def group_model=(klass)
        @group_model = klass
      end

      def permission_model
        @perm_model || ::Permission rescue nil
      end

      def group_model
        @group_model || ::Group rescue nil
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
