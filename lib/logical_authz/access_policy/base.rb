require 'logical_authz/debug'
require 'logical_authz/access_policy/dsl'

module LogicalAuthz
  module AccessPolicy
    class Rule
      include Debug

      def initialize
        @decision = false
        @name = nil
      end

      attr_accessor :name, :decision

      def name
        @name ||= "#{decision_text.sub(/^./){|ch| ch.upcase}} #{hypothesis_text}"
      end

      def decision_text
        if @decision
          "allow"
        else
          "deny"
        end
      end

      def hypothesis_text
        "if #{predicate_text}"
      end

      def predicate_text
        "<under undescribed conditions>"
      end

      def check(criteria)
        raise NotImplementedException
      end

      def evaluate(criteria)
        laz_debug{"Rule being examined: \"#{self.name}\""}
        if check(criteria) == true
          laz_debug{"Rule: \"#{self.name}\" triggered - authorization: #{decision_text}"}
          return @decision
        else
          return nil
        end
      rescue Object => ex
        Rails.logger.info{ "Exception raised checking rule \"#{self.name}\": #{ex.class.name}: #{ex.message} @ #{ex.backtrace[0..2].inspect}" }
        if Configuration.raise_policy_exceptions?
          raise
        else
          return false
        end
      end

      class << self
        def names
          @names ||= {}
        end

        def register(name)
          Rule.names[name.to_sym] = self
          Rule.names["if_#{name}".to_sym] = self

          AccessPolicy::Builder.register_policy_class(name, self)
        end
      end
    end
  end
end
