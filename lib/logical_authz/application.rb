module LogicalAuthz
  module Application
    def self.included(klass)
      klass.extend(ClassMethods)
    end
    include Helper

    def redirect_to_lobby(message = nil)
      back = request.headers["Referer"]
      Rails.logger.debug("Sending user back to: #{back} Authz'd?") if defined?(LAZ_DEBUG) and LAZ_DEBUG
      back_criteria = criteria_from_url(back)
      if back_criteria.nil? 
        Rails.logger.debug{"Back is nil - going to the default_unauthorized_url"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
        redirect_to default_unauthorized_url
      elsif LogicalAuthz::is_authorized?(back_criteria)
        Rails.logger.debug{"Back authorized - going to #{back}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
        redirect_to back
      else
        Rails.logger.debug{"Back is unauthorized - going to the default_unauthorized_url"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
        redirect_to default_unauthorized_url
      end
    end

    def strip_record(record)
      {
        :rule => record[:determining_rule].name,
        :logged_in => !record[:user].nil?,
        :reason => record[:reason],
        :result => record[:result]
      }
    end

    def check_authorized
      current_user = AuthnFacade.current_user(self)

      criteria = {
        :user => current_user, 
        :controller => self.class,
        :action => action_name, 
        :id => params[:id]
      }

      logical_authz_record = {:authz_path => request.path.dup}
      LogicalAuthz.is_authorized?(criteria, logical_authz_record)
      Rails.logger.debug{"Logical Authz result: #{logical_authz_record.inspect}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
      flash[:logical_authz_record] = strip_record(logical_authz_record)
      if logical_authz_record[:result]
        return true
      else
        request.session[:unauthzd_path] = request.path
        redirect_to_lobby("Your account is not authorized to perform this action.")
        return false
      end
    end

    module ClassMethods
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
        #if criteria[:group].empty?
        #  criteria[:group] += LogicalAuthz::unauthorized_groups
        #end
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

        Rails.logger.debug {"LogicalAuthz: final computed authz criteria: #{inspect_criteria(criteria)}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG

        return criteria
      end

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
          Rails.logger.debug{"Chekcing rule: #{control.inspect}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
          policy = control.evaluate(criteria)
          unless policy.nil?
            Rails.logger.debug{"Rule triggered - result: #{policy.inspect}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
            result_hash.merge! :determining_rule => control, :reason => :rule_triggered, :result => policy
            break 
          end
        end
        return policy
      end

      #It was tempting to build this on before_filter directly - however, 
      #inspecting a controller to see if a particular filter will run for a 
      #particular action is fragile.
      def needs_authorization(*actions)
        policy(*actions) do
          allow if_allowed {
            deny :authenticated
            allow AccessControl::Permitted.new({:group => LogicalAuthz.unauthorized_groups})
          }
          allow :permitted
          existing_policy
          deny :always
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def dynamic_authorization(&block)
        policy do |pol|
          allow(&block)
          existing_policy
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def owner_authorized(*actions, &block)
        policy(*actions) do |pol|
          allow AccessControl::Owner.new(&block)
          existing_policy
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def admin_authorized(*actions)
        policy(*actions) do |pol|
          allow :if_admin
          existing_policy
        end
      end
    end

    class CheckAuthorization
      def self.filter(controller)
        if controller.class.authorization_needed?(controller.action_name)
          return controller.check_authorized
        else
          Rails.logger.debug{"Logical Authorization: #{controller} doesn't need authz"}
          return true
        end
      end
    end
  end
end
