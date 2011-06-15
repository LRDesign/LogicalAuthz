require 'logical_authz/access_policy/sub_rules'

module LogicalAuthz
  module AccessPolicy
    class PolicyDefinitionError < ::Exception; end

    class Builder
      class << self
        def register_policy_class(name, klass)
          define_method(name) { klass.new }
          define_method("if_#{name}") { klass.new }
        end

        def register_policy_helper(name, &block)
          define_method(name, &block)
        end
      end

      def initialize(helper_mod = nil)
        @helper_mod = helper_mod
        @list = @before = []
        @after = []

        (class << self; self; end).instance_eval do
          include(helper_mod) unless helper_mod.nil?
        end
      end

      def define(&block)
        instance_eval(&block)
      end

      def resolve_rule(rule)
        case rule
        when Rule #This is the important case, actually
        when Symbol, String
          klass = Rule.names[rule.to_sym]
          raise "Rule name #{rule} not found in #{Rule.names.keys.inspect}" if klass.nil?
          Rails.logger.warn { "Using deprecated string/symbol policy naming: #{rule.inspect}" }
          rule = klass.new
        when Class
          rule = rule.new
          unless rule.responds_to?(:check)
            raise "Rule classes must respond to #check"
          end
        when Proc
          rule = ProcRule.new(&rule)
        else
          raise PolicyDefinitionError, "Authorization Rules have to be Rule objects, a Rule class or a proc"
        end
        rule
      end

      #TODO DSL needs to allow config of rules
      def add_rule(rule, allows = true, name = nil)
        rule = resolve_rule(rule)

        rule.decision = allows
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

      def if_allowed(&block)
        IfAllows.new(@helper_mod, &block)
      end

      def if_denied(&block)
        IfDenies.new(@helper_mod, &block)
      end

      def related(&block)
        raise PolicyDefinitionError, "related called without a block" if block.nil?
        Owner.new(&block)
      end

      def except(policy) #This needs a different name
        policy = resolve_rule(policy)
        Reversed.new(policy)
      end

      def with_criteria(policy, &block)
        raise PolicyDefinitionError, "with_criteria called without a block" if block.nil?
        policy = resolve_rule(policy)
        RemappedCriteria.new(policy, &block)
      end

      def existing_policy
        @list = @after
      end

      def list(existing = nil)
        existing ||= []
        result = @before + existing + @after
      end
    end
  end
end

