module LogicalAuthz
  module Matcher
    class Authorized
      def initialize
        @controller = nil
      end

      def match_state
        "authorized"
      end

      def check_authorization_flag
        return false unless @flash.has_key? :logical_authz_record
        return true if @flash[:logical_authz_record][:result] == true
        return false
      end

      def matches?(controller)
        @controller = controller
        @flash = controller.__send__(:flash)
        #controller should be a controller
        return check_authorization_flag
      end

      def failure_message(match_text)
        if @flash.has_key? :logical_authz_record
          laz_rec = @flash[:logical_authz_record]
          "Expected #{@controller.class.name}(#{@controller.params.inspect})" + 
            " #{match_text} #{match_state}, but flash[:logical_authz_record][:result] " + 
              "is <#{laz_rec[:result].inspect}> (reason: #{laz_rec[:reason].inspect}, " +
            "rule: #{laz_rec[:determining_rule].try(:name)})"
        else
          "Expected #{@controller.class.name}(#{@controller.params.inspect}) #{match_text} #{match_state}, but flash did not have key :logical_authz_record"
        end
      end

      def failure_message_for_should
        failure_message("to be")
      end

      def failure_message_for_should_not
        failure_message("not to be")
      end
    end

    class Forbidden < Authorized
      def match_state
        "forbidden"
      end

      def check_authorization_flag
        return false unless @flash.has_key? :logical_authz_record
        return true if @flash[:logical_authz_record][:result] == false
        return false
      end
    end
  end


  module ControllerExampleGroupMixin
    def be_authorized
      return Matcher::Authorized.new
    end

    def be_forbidden
      return Matcher::Forbidden.new
    end
  end
end

module RSpec::Rails::Example
  class ControllerExampleGroup
    include LogicalAuthz::ControllerExampleGroupMixin
  end
end
