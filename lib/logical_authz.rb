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
  end


  def self.is_authorized?(criteria={})
    criteria ||= {}

    controller_class = ::ApplicationController

    case criteria[:controller]
    when Class
      if LogicalAuthz::Application > criteria[:controller]
        controller_class = criteria[:controller]
      end
    when LogicalAuthz::Application
      controller_class = criteria[:controller].class
    when String, Symbol
      controller_class_name = criteria[:controller].to_s.camelize + "Controller"
      begin 
        controller_class = controller_class_name.constantize
      rescue NameError
      end
    end

    return true unless controller_class.authorization_needed?(criteria[:action])

    #TODO Fail if controller unspecified?

    criteria[:group] = criteria[:group].nil? ? [] : [*criteria[:group]]
    if criteria.has_key?(:user) and not criteria[:user].nil?
      criteria[:group] += criteria[:user].groups
    end
    if criteria[:group].empty?
      criteria[:group] += unauthorized_groups
    end
    criteria[:group], not_groups = criteria[:group].partition do |group|
      LogicalAuthz::group_model === group
    end
    Rails.logger.warn "Found in criteria[:groups]: #{not_groups.inspect}"

    #TODO Fail if group unspecified and user unspecified?

    actions = [*criteria[:action]].compact
    criteria[:action_aliases] = actions.map do |action|
      controller_class.grant_aliases_for(action)
    end.flatten + actions.map{|action| action.to_sym}

    controller_class.authorization_procs.each do |prok|
      approval = prok.call(criteria[:user], criteria) #Tempted to remove the user param
      next if approval == false
      next if approval.blank?
      return true
    end

    select_on = {
      :group_ids => criteria[:group].map {|grp| grp.id},
      :controller => controller_class.controller_path,
      :action_names => criteria[:action_aliases].map {|a| a.to_s},
      :subject_id => criteria[:id] 
    }

    Rails.logger.debug{ select_on.inspect }
    allowed = LogicalAuthz::permission_model.exists?([PermissionSelect, select_on])
    Rails.logger.info{ "Denied: #{select_on.inspect}"} unless allowed
    return allowed
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
      if back.nil? 
        Rails.logger.debug{"Back is nil - going to the default_unauthorized_url"}
        redirect_to default_unauthorized_url
      elsif back_criteria = criteria_from_url(back) && LogicalAuthz::is_authorized?(back_criteria)
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

      if LogicalAuthz.is_authorized?(criteria)
        flash[:group_authorization] = true
        return true
      else
        redirect_to_lobby("Your account is not authorized to perform this action.")
        flash[:group_authorization] = false
        return false
      end
    end

    module ClassMethods
      #It was tempting to build this on before_filter directly - however, 
      #inspecting a controller to see if a particular filter will run for a 
      #particular action is fragile.
      def needs_authorization(*actions)
        before_filter CheckAuthorization
        if actions.empty?
          write_inheritable_attribute(:authorization_policy, true)
        else
          action_hash = {}
          actions.each do |action|
            action_hash[action.to_sym] = true
          end
          write_inheritable_hash(:action_authorization, action_hash)
        end
      end

      def publicly_allowed(*actions)
        if actions.empty?
          write_inheritable_attribute(:authorization_policy, false)
        else
          action_hash = {}
          actions.each do |action|
            action_hash[action.to_sym] = false
          end

          write_inheritable_hash(:action_authorization, action_hash)
        end
      end

      def authorization_needed?(action)
        action = action.to_sym
        policies = read_inheritable_attribute(:action_authorization) || {}
        default_policy = read_inheritable_attribute(:authorization_policy) || false
        if action.nil?
          return default_policy
        end

        if policies.has_key?(action)
          return policies[action]
        end

        return default_policy
      end

      # grant_aliases :new => :create  # =>
      # anyone with :new permission can do :create
      def grant_aliases(hash)
        aliases = read_inheritable_attribute(:grant_alias_hash) || Hash.new{|h,k| h[k] = []}
        hash.each_pair do |grant, allows|
          [*allows].each do |allowed|
            aliases[allowed.to_sym] << grant.to_sym
          end
        end
        write_inheritable_attribute(:grant_alias_hash, aliases)
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

      def dynamic_authorization(&block)
        write_inheritable_array(:dynamic_authorization_procs, [proc &block])
      end

      def authorization_procs
        read_inheritable_attribute(:dynamic_authorization_procs) || []
      end

      def owner_authorized(*actions)
        actions.map!{|action| action.to_sym}
        dynamic_authorization do |user, criteria|
          unless actions.nil? or actions.empty?
            return false if (actions & criteria[:action_aliases]).empty?
          end
          return false unless criteria.has_key?(:user) and criteria.has_key?(:id)
          if block_given?
            yield(criteria[:user], criteria[:id].to_i) rescue false
          else
            criteria[:user].id == criteria[:id].to_i
          end
        end
      end

      def admin_authorized(*actions)
        actions.map!{|action| action.to_sym}
        dynamic_authorization do |user, criteria|
          unless actions.nil? or actions.empty?
            return false if (actions & criteria[:action_aliases]).empty?
          end
          return criteria[:group].include?(Group.admin_group)
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
