require 'logical_authz_helper'

module LogicalAuthz
  PermissionSelect = "controller = :controller AND " +
    "group_id IN (:group_ids) AND " +
    "((action IS NULL AND subject_id IS NULL) OR " +
    "(action IN (:action_names) AND " +
    "(subject_id IS NULL OR subject_id = :subject_id)))"

  class << self
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

    attr_accessor :unauthorized_group_names

    def unauthorized_group_names
      @unauthorized_group_names ||= []
    end

    def inspect_criteria(criteria)
      criteria.inject({}) do |hash, name_value|
        name, value = *name_value
        case value
        when ActiveRecord::Base
          hash[name] = {value.class.name => value.id}
        when ActionController::Base
          hash[name] = value.class
        else
          hash[name] = value
        end

        hash
      end.inspect
    end

    def find_controller(reference)
      klass = nil

      case reference
      when Class
        if LogicalAuthz::Application > reference
          klass = reference
        end
      when LogicalAuthz::Application
        klass = reference.klass
      when String, Symbol
        klass_name = reference.to_s.camelize + "Controller"
        begin 
          klass = klass_name.constantize
        rescue NameError
        end
      end

      return klass
    end

    def check_controller(klass)
      if klass.nil?
        raise "Could not determine controller class - criteria[:controller] => #{criteria[:controller]}"
      end
    end

    def check_permitted(criteria)
      select_on = {
        :group_ids => criteria[:group].map {|grp| grp.id},
        :controller => criteria[:controller_path],
        :action_names => criteria[:action_aliases].map {|a| a.to_s},
        :subject_id => criteria[:id] 
      }

      Rails.logger.debug{ "LogicalAuthz: checking permissions: #{select_on.inspect}" }
      allowed = LogicalAuthz::permission_model.exists?([PermissionSelect, select_on])
      unless allowed
        Rails.logger.info{ "Denied: #{select_on.inspect}"} 
      else
        Rails.logger.info{ "Allowed: #{select_on.inspect}"} 
      end
      return allowed
    end

    def is_authorized?(criteria=nil, authz_record=nil)
      criteria ||= {}
      authz_record ||= {}
      authz_record.merge! :criteria => criteria, :result => nil, :reason => nil

      Rails.logger.debug{"LogicalAuthz: asked to authorize #{inspect_criteria(criteria)}"}

      controller_class = find_controller(criteria[:controller])
      
      Rails.logger.debug{"LogicalAuthz: determined controller: #{controller_class.name}"}

      check_controller(controller_class)

      unless controller_class.authorization_needed?(criteria[:action])
        Rails.logger.debug{"LogicalAuthz: controller says no authz needed."}
        authz_record.merge! :reason => :no_authorization_needed, :result => true
      else
        Rails.logger.debug{"LogicalAuthz: checking authorization"}

        controller_class.normalize_criteria(criteria)

        #TODO Fail if group unspecified and user unspecified?

        unless (acl_result = controller_class.check_acls(criteria, authz_record)).nil?
          authz_record[:result] = acl_result
        else
          authz_record.merge! :reason => :default, :result => controller_class.default_authorization
        end
      end

      Rails.logger.debug{authz_record.inspect}

      return authz_record[:result]
    end
  end

  module Application
    def self.included(klass)
      klass.extend(ClassMethods)
    end
    include Helper

    def redirect_to_lobby(message = "You aren't authorized for that")
      flash[:error] = message

      back = request.headers["Referer"]
      Rails.logger.debug("Going: #{back} authz'd?")
      back_criteria = criteria_from_url(back)
      if back_criteria.nil? 
        Rails.logger.debug{"Back is nil - going to the default_unauthorized_url"}
        redirect_to default_unauthorized_url
      elsif LogicalAuthz::is_authorized?(back_criteria)
        Rails.logger.debug{"Back authorized - going to #{back}"}
        redirect_to back
      else
        Rails.logger.debug{"Back is unauthorized - going to the default_unauthorized_url"}
        redirect_to default_unauthorized_url
      end
    end

    def check_authorized
      current_user = AuthnFacade.current_user(self)

      criteria = {
        :user => current_user, 
        :controller => self.class,
        :action => action_name, 
        :id => params[:id]
      }

      flash[:logical_authz_record] = {:authz_path => request.path.dup}
      if LogicalAuthz.is_authorized?(criteria, flash[:logical_authz_record])
        return true
      else
        redirect_to_lobby("Your account is not authorized to perform this action.")
        return false
      end
    end

    module ClassMethods
      #It was tempting to build this on before_filter directly - however, 
      #inspecting a controller to see if a particular filter will run for a 
      #particular action is fragile.
      def needs_authorization(*actions)
        policy(*actions) do
          allow :permitted
          deny :always
        end
      end

      def publicly_allowed(*actions)
        if actions.empty?
          authorization_by_default(true)
          reset_policy
        else
          reset_policy(*actions)
          policy(*actions) do |pol|
            allow :always
          end
        end
      end

      def policy(*actions, &block)
        before_filter CheckAuthorization
        builder = AccessControl::Builder.new
        builder.define(&block)
        if actions.empty?
          set_policy(builder.list(get_policy(nil)), nil)
        else
          actions = unalias_actions(actions)
          actions.each do |action|
            set_policy(builder.list(get_policy(action)), action)
          end
        end
      end

      def reset_policy(*actions)
        if actions.empty?
          set_policy([], nil)
        else
          unalias_actions(actions).each do |action|
            set_policy([], action)
          end
        end
      end

      def clear_policies!
        write_inheritable_attribute(:controller_access_control, [])
        write_inheritable_attribute(:action_access_control, {})
      end

      def get_policy(action)
        if action.nil?
          read_inheritable_attribute(:controller_access_control) || []
        else
          (read_inheritable_attribute(:action_access_control) || {})[action.to_sym]
        end
      end

      def set_policy(acl, action)
        if action.nil?
          write_inheritable_attribute(:controller_access_control, acl)
        else
          write_inheritable_hash(:action_access_control, {})
          policies = read_inheritable_attribute(:action_access_control)
          policies[action.to_sym] = acl
        end
      end

      def authorization_by_default(default_allow)
        write_inheritable_attribute(:authorization_policy, default_allow)
      end

      def default_authorization
        policy = read_inheritable_attribute(:authorization_policy)
        if policy.nil?
          true
        else
          policy
        end
      end

      def authorization_needed?(action)
        acl = access_controls(action)
        return true unless acl.empty?
        return !read_inheritable_attribute(:authorization_policy) || false
      end

      def move_policies(from, to)
        policies = read_inheritable_attribute(:action_access_control)
        if policies.nil?
          policies = {}
          write_inheritable_attribute(:action_access_control, policies)
        end

        if policies.has_key?(from.to_sym)
          if policies.has_key?(to.to_sym)
            #Should be raise, at some future point
            warn "Moving policies defined on #{self.name} for #{from} would clobber policies on #{to}"
          end
          policies[to.to_sym] = policies[from.to_sym]
          policies.delete(from.to_sym)
        end
      end

      # grant_aliases :new => :create  # =>
      # anyone with :new permission can do :create
      def grant_aliases(hash)
        aliases = read_inheritable_attribute(:grant_alias_hash) || Hash.new{|h,k| h[k] = []}
        aliased = read_inheritable_attribute(:aliased_grants) || {}
        hash.each_pair do |grant, allows|
          [*allows].each do |allowed|
            aliases[allowed.to_sym] << grant.to_sym
            aliased[grant.to_sym] = allowed.to_sym
            move_policies(grant, allowed)
          end
        end
        write_inheritable_attribute(:grant_alias_hash, aliases)
        write_inheritable_attribute(:aliased_grants, aliased)
      end
      
      def unalias_actions(actions)
        aliased_actions = read_inheritable_attribute(:aliased_grants) || {}
        actions.map do |action|
          aliased_actions[action.to_sym] || action
        end.compact.uniq
      end

      def grant_aliases_for(action)
        grant_aliases = read_inheritable_attribute(:grant_alias_hash)
        action = action.to_sym

        if not grant_aliases.nil? and grant_aliases.has_key?(action)
          return grant_aliases[action]
        else
          return []
        end
      end

      def inspect_criteria(criteria)
        criteria.inject({}) do |hash, name_value|
          name, value = *name_value
          case value
          when ActiveRecord::Base
            hash[name] = {value.class.name => value.id}
          when ActionController::Base
            hash[name] = value.class
          else
            hash[name] = value
          end

          hash
        end.inspect
      end

      def normalize_criteria(criteria)
        criteria[:group] = criteria[:group].nil? ? [] : [*criteria[:group]]
        if criteria.has_key?(:user) and not criteria[:user].nil?
          criteria[:group] += criteria[:user].groups
        end
        if criteria[:group].empty?
          criteria[:group] += LogicalAuthz::unauthorized_groups
        end
        criteria[:group], not_groups = criteria[:group].partition do |group|
          LogicalAuthz::group_model === group
        end
        Rails.logger.warn{ "Found in criteria[:groups]: #{not_groups.inspect}"} unless not_groups.empty?
        actions = [*criteria[:action]].compact
        criteria[:action_aliases] = actions.map do |action|
          grant_aliases_for(action)
        end.flatten + actions.map{|action| action.to_sym}

        criteria[:controller] = self
        criteria[:controller_path] = controller_path

        Rails.logger.debug {"LogicalAuthz: final computed authz criteria: #{inspect_criteria(criteria)}"}

        return criteria
      end

#      def check_acls(criteria)
#        Rails.logger.debug {"LogicalAuthz: checking authz procs"}
#        authorization_procs.each do |prok|
#          approval = prok.call(criteria)
#          next if approval == false
#          next if approval.blank?
#          Rails.logger.debug {"LogicalAuthz: authorized by #{prok.inspect}"}
#          return true
#        end
#        return false
#      end

      def access_controls(action)
        action = unalias_actions([action]).first
        action_acl = (read_inheritable_attribute(:action_access_control) || {})[action.to_sym] || []
        controller_acl = read_inheritable_attribute(:controller_access_control) || []
        action_acl + controller_acl
      end

      def check_acls(criteria, result_hash = nil)
        result_hash ||= {}
        policy = nil
        acl = access_controls(criteria[:action])
        result_hash.merge! :checked_rules => [], :determining_rule => nil, :all_rules => acl
        acl.each do |control|
          result_hash[:checked_rules] << control
          policy = control.evaluate(criteria)
          unless policy.nil?
            result_hash.merge! :determining_rule => control, :reason => :rule_triggered, :result => policy
            break 
          end
        end
        return policy
      end

      module AccessControl
        class Builder
          def initialize
            @list = @before = []
            @after = []
          end

          def define(&block)
            instance_eval(&block)
          end

          def add_rule(rule, allows = true, name = nil)
            case rule
            when Policy
            when Symbol, String
              klass = Policy.names[rule.to_sym]
              raise "Policy name #{rule} not found in #{Policy.names.keys.inspect}" if klass.nil?
              rule = klass.new(allows)
            when Class
              rule = rule.new(allows)
              unless rule.responds_to?(:check)
                raise "Policy classes must respond to #check"
              end
            when Proc
              rule = ProcPolicy.new(allows, &rule)
            else
              raise "Authorization Rules have to be Policy objects, a Policy class or a proc"
            end

            rule.name = name unless name.nil?
            @list << rule
          end

          def allow(rule = nil, name = nil, &block)
            if rule.nil?
              if block.nil?
                raise "Allow needs to have a rule or a block"
              end
              rule = block
            end
            add_rule(rule, true, name)
          end

          def deny(rule = nil, name = nil, &block)
            if rule.nil?
              if block.nil?
                raise "Deny needs to have a rule or a block"
              end
              rule = block
            end
            add_rule(rule, false, name)
          end

          def existing_policy
            @list = @after
          end

          def list(existing = nil)
            existing ||= []
            @before + existing + @after
          end
        end

        class Policy
          def initialize(allows)
            @decision = allows
            @name = default_name
          end

          attr_accessor :name

          def default_name
            "Unknown Rule"
          end

          def check(criteria)
            raise NotImplementedException
          end

          def evaluate(criteria)
            if check(criteria) == true
              Rails::logger.debug{"Rule: #@name triggered - authorization allowed: #@decision"}
              return @decision
            else
              return nil
            end
          end

          class << self
            def names
              @names ||= {}
            end

            def register(name)
              Policy.names[name.to_sym] = self
            end
          end
        end

        class Always < Policy
          register :always

          def default_name
            "Always"
          end

          def check(criteria)
            true
          end
        end

        class Administrator < Policy
          register :if_admin

          def default_name
            "Admins"
          end

          def check(criteria)
            return criteria[:group].include?(Group.admin_group)
          end
        end

        class Owner < Policy
          register :if_owner

          def initialize(allows, &map_owner)
            @mapper = map_owner
            super(allows)
          end

          def default_name
            "Owner"
          end

          def check(criteria)
            return false unless criteria.has_key?(:user) and criteria.has_key?(:id)
            unless @mapper.nil?
              @mapper.call(criteria[:user], criteria[:id].to_i) rescue false
            else
              criteria[:user].id == criteria[:id].to_i
            end
          end
        end

        class Permitted < Policy
          register :permitted
          def initialize(allows, specific_criteria = {})
            @criteria = specific_criteria
            super(allows)
          end

          def default_name
            "Permitted"
          end

          def check(criteria)
            crits = criteria.merge(@criteria)
            return LogicalAuthz::check_permitted(crits)
          end
        end

        class ProcPolicy < Policy
          def initialize(allows, &check)
            @check = check
            super(allows)
          end

          def check(criteria)
            @check.call(criteria)
          end
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def dynamic_authorization(&block)
        policy do |pol|
          allow(&block)
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def owner_authorized(*actions, &block)
        policy(*actions) do |pol|
          allow AccessControl::Owner.new(true, &block)
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def admin_authorized(*actions)
        policy(*actions) do |pol|
          allow :if_admin
        end
      end
    end

    class CheckAuthorization
      def self.filter(controller)
        if controller.class.authorization_needed?(controller.action_name)
          return controller.check_authorized
        else
          return true
        end
      end
    end
  end
end
