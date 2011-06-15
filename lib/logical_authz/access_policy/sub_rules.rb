require 'logical_authz/access_policy/base'

module LogicalAuthz
  module AccessPolicy
    class Rule
    end

    class SubRule < Rule
      def initialize(helper_mod, &block)
        super()
        builder = Builder.new(helper_mod)
        builder.define(&block)
        @rule_list = builder.list
      end

      def check(criteria)
        @rule_list.each do |rule|
          policy = rule.evaluate(criteria)
          next if policy.nil?
          return match_policy(policy)
        end
        return false
      end
    end

    class IfAllows < SubRule
      def predicate_text
        "allowed by..."
      end

      def match_policy(policy)
        policy == true
      end
    end

    class IfDenies < SubRule
      def predicate_text
        "denied by..."
      end

      def match_policy(policy)
        policy == false
      end
    end
  end
end
