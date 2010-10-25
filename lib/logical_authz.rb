#require 'logical_authz_helper'
require 'logical_authz/access_control'
require 'logical_authz/application'

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

      Rails.logger.debug{ "LogicalAuthz: checking permissions: #{select_on.inspect}" } if defined?(LAZ_DEBUG) && LAZ_DEBUG
      allowed = LogicalAuthz::permission_model.exists?([PermissionSelect, select_on])
      unless allowed
        Rails.logger.debug{ "Denied: #{select_on.inspect}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
      else
        Rails.logger.debug{ "Allowed: #{select_on.inspect}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG
      end
      return allowed
    end


    def is_authorized?(criteria=nil, authz_record=nil)
      criteria ||= {}
      authz_record ||= {}
      authz_record.merge! :criteria => criteria, :result => nil, :reason => nil

      Rails.logger.debug{"LogicalAuthz: asked to authorize #{inspect_criteria(criteria)}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG

      controller_class = find_controller(criteria[:controller])
      
      Rails.logger.debug{"LogicalAuthz: determined controller: #{controller_class.name}"} if defined?(LAZ_DEBUG) and LAZ_DEBUG

      check_controller(controller_class)

      unless controller_class.authorization_needed?(criteria[:action])
        Rails.logger.debug{"LogicalAuthz: controller says no authz needed."} if defined?(LAZ_DEBUG) and LAZ_DEBUG
        authz_record.merge! :reason => :no_authorization_needed, :result => true
      else
        Rails.logger.debug{"LogicalAuthz: checking authorization"} if defined?(LAZ_DEBUG) and LAZ_DEBUG

        controller_class.normalize_criteria(criteria)

        #TODO Fail if group unspecified and user unspecified?

        unless (acl_result = controller_class.check_acls(criteria, authz_record)).nil?
          authz_record[:result] = acl_result
        else
          authz_record.merge! :reason => :default, :result => controller_class.default_authorization
        end
      end

      Rails.logger.debug{authz_record.inspect} if defined?(LAZ_DEBUG) and LAZ_DEBUG

      return authz_record[:result]
    end
  end
end
