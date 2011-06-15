require 'logical_authz/access_policy/base'

module LogicalAuthz
  module AccessPolicy
  
    #The policy rule of last resort
    class ProcRule < Rule
      def initialize(&check)
        @check = check
        super()
      end

      def check(criteria)
        @check.call(criteria)
      end
    end

    class Always < Rule
      register :always

      def predicate_text
        "always"
      end
      alias hypothesis_text predicate_text

      def check(criteria)
        true
      end
    end

    class Reversed < Rule
      def initialize(other)
        @other = other
        super()
      end

      def predicate_text
        "unless #{@other.predicate_text}"
      end
      alias hypothesis_text predicate_text

      def check(criteria)
        !@other.check(criteria)
      end
    end

    class RemappedCriteria < Rule
      def initialize(other, &block)
        @other = other
        @block = block
        super()
      end

      def predicate_text
        "#{@other.predicate_text} (with remapped criteria)"
      end

      def check(criteria)
        new_criteria = criteria.dup
        laz_debug{ {:Remapping => new_criteria} }
        @block.call(new_criteria)
        laz_debug{ {:Remappped => new_criteria} }
        @other.check(new_criteria)
      end
    end

    class Administrator < Rule
      register :admin

      def predicate_text
        "administrator"
      end

      def check(criteria)
        return criteria[:roles].any? do |role| 
          LogicalAuthz::Configuration.admin_role?(role)
        end
      end
    end

    class Authenticated < Rule
      register :authenticated

      def predicate_text
        "authenticated"
      end

      def check(criteria)
        criteria[:user] != nil
      end
    end

    class Authorized < Rule
      register :authorized

      def predicate_text
        "authorized"
      end

      def check(criteria)
        criteria[:authorization_depth] ||= 0
        criteria[:authorization_depth] += 1

        if criteria[:authorization_depth] > 10
          raise "Authorization recursion limit reached" 
        end

        LogicalAuthz.is_authorized?(criteria)
      end
    end

    class Owner < Rule
      register :owner

      def initialize(&map_owner)
        @mapper = map_owner
        super()
      end

      def predicate_text
        if @mapper
          "related"
        else
          "own user record"
        end
      end

      def check(criteria)
        return false unless criteria.has_key?(:user) and criteria.has_key?(:id)
        unless @mapper.nil?
          @mapper.call(criteria[:user], criteria[:id].to_i)
        else
          criteria[:user].id == criteria[:id].to_i
        end
      end
    end
  end
end
