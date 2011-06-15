require 'logical_authz/debug'
require 'logical_authz/policy_enforcement'

module LogicalAuthz
  module Application
    include Debug
    include PolicyEnforcement

    def self.included(klass)
      klass.extend(ClassMethods)
    end
    #include Helper

    def redirect_to_lobby(message = nil)
      back = request.headers["Referer"]
      laz_debug{"Sending user back to: #{back.inspect} Authz'd?"}
      back_criteria = criteria_from_url(back) #because back might be foreign
      if !back.nil? and authorized?(back_criteria)
        laz_debug{"Back authorized - going to #{back}"}
        redirect_to back
      else
        laz_debug{
          if back_criteria.nil?
            "Back is nil - trying authz fallback"
          else
            "Back is unauthorized - trying authz fallback"
          end
        }
        #TODO: list of fallbacks, with defaults?
        LogicalAuthz::Configuration.divert_urls.each do |url|

          if authorized_url?(url)
            laz_debug{"#{url} is authz'd - redirecting"}
            redirect_to url
            return
          else
            laz_debug{"#{url} is NOT authz'd - trying next"}
          end
        end
        redirect_to root_url
      end
    end

    def redirect_to_last_unauthorized(message = nil)
      message ||= "Login successful"
      if (laz_session = session[:logical_authz]) && (unauthorized = laz_session[:unauthzd_path])
        laz_debug{{:going_to_last_unauth => laz_session}.inspect}
        redirect_to(unauthorized, :flash => {:success => message})
      else
        laz_debug{{:going_root => laz_session}.inspect}
        redirect_to(:root, :flash => {:success => message})
      end
    end
    alias redirect_retry redirect_to_last_unauthorized

    def strip_record(record)
      laz_debug{"Logical Authz: stripping: #{record.inspect}"}
      {
        :rule => record[:determining_rule].try(:name),
        :logged_in => !(record[:criteria] || {})[:user].nil?,
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
        :id => params[:id],
        :params => params.dup
      }

      logical_authz_record = {:authz_path => request.path.dup}
      LogicalAuthz.is_authorized?(criteria, logical_authz_record)
      laz_debug{"Result: #{logical_authz_record.inspect}"}
      flash[:logical_authz_record] = strip_record(logical_authz_record)
      laz_debug{"Stripped to: #{flash[:logical_authz_record].inspect}"}
      if logical_authz_record[:result]
        return true
      else
        request.session[:logical_authz] ||= {}
        request.session[:logical_authz][:unauthzd_path] = request.path
        flash[:logical_authz_last_denial] = flash[:logical_authz_record]

        redirect_to_lobby("Your account is not authorized to perform this action.")
        return false
      end
    end

    module ClassMethods
      include Debug

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

      def policy_helper_module
        @policy_helper_module ||= 
          begin
            mod = Module.new
            parent_mod = read_inheritable_attribute(:policy_helper_module)
            unless parent_mod.nil?
              mod.class_eval {
                include(parent_mod)
              }
            end
            write_inheritable_attribute(:policy_helper_module, mod)
            mod
          end
      end

      def policy_helper(name, &body)
        policy_helper_module.module_eval do
          define_method name, &body
        end
      end

      def policy(*actions, &block)
        before_filter CheckAuthorization
        builder = AccessPolicy::Builder.new(policy_helper_module)
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
          laz_debug{ "Policy set: #{self.name} - all: #{acl.inspect}" }
          write_inheritable_attribute(:controller_access_control, acl)
        else
          laz_debug{ "Policy set: #{self.name}##{action}: #{acl.inspect}" }
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
      # anyone with authorization to :create can also access :new
      # (Read as: "for 'new' read 'create'")
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
      alias grant_alias grant_aliases
      
      def standard_grant_aliases
        grant_aliases :edit => :update
      end

      def unalias_actions(actions)
        aliased_actions = read_inheritable_attribute(:aliased_grants) || {}
        actions.compact.map do |action|
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

      def normalize_criteria(criteria)
        criteria[:roles] = criteria[:roles].nil? ? [] : [*criteria[:roles]]
        if criteria.has_key?(:user) and not criteria[:user].nil?
          criteria[:roles] += criteria[:user].roles
        end
        criteria[:roles], not_roles = criteria[:roles].partition do |roles|
          Role === roles
        end
        Rails.logger.warn{ "Found in criteria[:roles]: #{not_roles.inspect}"} unless not_roles.empty?

        actions = [*criteria[:action]].compact
        criteria[:action_aliases] = actions.map do |action|
          grant_aliases_for(action)
        end.flatten + actions.map{|action| action.to_sym}

        criteria[:controller] = self
        criteria[:controller_path] = controller_path

        laz_debug{"LogicalAuthz: final computed authz criteria: #{inspect_criteria(criteria)}"}

        return criteria
      end

      def access_controls(action)
        controller_acl = read_inheritable_attribute(:controller_access_control) || []
        return controller_acl if action.nil?
        action = unalias_actions([action]).first
        action_acl = (read_inheritable_attribute(:action_access_control) || {})[action.to_sym] || []
        laz_debug{ { :checking_policy_for => action, :policies_exist_for => (read_inheritable_attribute(:action_access_control) || {}).keys, :action_acl => action_acl, :controller_acl => controller_acl } }
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
            laz_debug{"Rule triggered - result: #{policy.inspect}"}
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
            deny authenticated
            allow if_permitted(:roles => LogicalAuthz::Configuration.unauthorized_roles)
          }
          allow if_permitted
          existing_policy
        end

        policy do
          existing_policy
          deny :always
        end
      end

      alias authorized_if_permitted needs_authorization

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
          allow if_owner(&block)
          existing_policy
        end
      end

      #This method exists for backwards compatibility.  It's likely more 
      #readable to use the policy DSL
      def admin_authorized(*actions)
        policy(*actions) do |pol|
          allow if_admin
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
