require 'logical_authz/access_policy'
require 'logical_authz/application'
require 'logical_authz/configuration'
require 'logical_authz/debug'
require 'logical_authz/authenticated_entity'

module LogicalAuthz
  include Debug

  class << self
    include Debug

    def find_controller(reference)
      klass = nil

      case reference
      when Class
        if LogicalAuthz::Application > reference
          klass = reference
        end
      when LogicalAuthz::Application
        klass = reference.class
      when String, Symbol
        klass_name = reference.to_s.camelize + "Controller"
        begin 
          klass = klass_name.constantize
        rescue NameError
        end
      end

      return klass
    end

    def check_controller(klass, from_criteria)
      if klass.nil?
        raise "Could not determine controller class - criteria[:controller] => #{from_criteria}"
      end
    end


    def is_authorized?(criteria=nil, authz_record=nil)
      criteria ||= {}
      authz_record ||= {}
      authz_record.merge! :criteria => criteria, :result => nil, :reason => nil

      laz_debug{"LogicalAuthz: asked to authorize #{inspect_criteria(criteria)}"}

      controller_class = find_controller(criteria[:controller])
      
      laz_debug{"LogicalAuthz: determined controller: #{controller_class.name}"}

      check_controller(controller_class, criteria[:controller])

      unless controller_class.authorization_needed?(criteria[:action])
        laz_debug{"LogicalAuthz: controller says no authz needed."}
        authz_record.merge! :reason => :no_authorization_needed, :result => true
      else
        laz_debug{"LogicalAuthz: checking authorization"}

        controller_class.normalize_criteria(criteria)

        #TODO Fail if group unspecified and user unspecified?

        unless (acl_result = controller_class.check_acls(criteria, authz_record)).nil?
          authz_record[:result] = acl_result
        else
          authz_record.merge! :reason => :default, :result => controller_class.default_authorization
        end
      end

      laz_debug{authz_record}

      return authz_record[:result]
    end
  end
end
