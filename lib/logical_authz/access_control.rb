module LogicalAuthz
  module AccessControl
    class Builder
      def initialize
        @list = @before = []
        @after = []
      end

      def define(&block)
        instance_eval(&block)
      end

      #TODO DSL needs to allow config of rules
      def add_rule(rule, allows = true, name = nil)
        case rule
        when Policy
        when Symbol, String
          klass = Policy.names[rule.to_sym]
          raise "Policy name #{rule} not found in #{Policy.names.keys.inspect}" if klass.nil?
          rule = klass.new(allows)
        when Class
          rule = rule.new(allows)
          unless rule.responds_to?(:check)
            raise "Policy classes must respond to #check"
          end
        when Proc
          rule = ProcPolicy.new(allows, &rule)
        else
          raise "Authorization Rules have to be Policy objects, a Policy class or a proc"
        end

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

      def existing_policy
        @list = @after
      end

      def list(existing = nil)
        existing ||= []
        @before + existing + @after
      end
    end

    class Policy
      def initialize(allows)
        @decision = allows
        @name = default_name
      end

      attr_accessor :name

      def default_name
        "Unknown Rule"
      end

      def check(criteria)
        raise NotImplementedException
      end

      def evaluate(criteria)
        if check(criteria) == true
          Rails::logger.debug{"Rule: #@name triggered - authorization allowed: #@decision"}
          return @decision
        else
          return nil
        end
      end

      class << self
        def names
          @names ||= {}
        end

        def register(name)
          Policy.names[name.to_sym] = self
        end
      end
    end

    class Always < Policy
      register :always

      def default_name
        "Always"
      end

      def check(criteria)
        true
      end
    end

    class SubPolicy < Policy
      def initialize(decision, &block)
        super(decision)
        builder = Builder.new
        builder.define(&block)
        @criteria_list = builder.list
      end

      def check(criteria)
        @criteria_list.each do |control|
          policy = control.evaluate(criteria)
          next if policy.nil?
          return match_policy(policy)
        end
        return false
      end
    end

    class IfAllows < SubPolicy
      register :if_allows

      def default_name
        "If allowed by..."
      end

      def match_policy(policy)
        policy == true
      end
    end

    class IfDenies < SubPolicy
      register :if_denies

      def default_name
        "If denied by..."
      end

      def match_policy(policy)
        policy == false
      end
    end

    class Administrator < Policy
      register :if_admin

      def default_name
        "Admins"
      end

      def check(criteria)
        return criteria[:group].include?(Group.admin_group)
      end
    end

    class Owner < Policy
      register :if_owner

      def initialize(allows, &map_owner)
        @mapper = map_owner
        super(allows)
      end

      def default_name
        "Owner"
      end

      def check(criteria)
        return false unless criteria.has_key?(:user) and criteria.has_key?(:id)
        unless @mapper.nil?
          @mapper.call(criteria[:user], criteria[:id].to_i) rescue false
        else
          criteria[:user].id == criteria[:id].to_i
        end
      end
    end

    class Permitted < Policy
      register :permitted
      def initialize(allows, specific_criteria = {})
        @criteria = specific_criteria
        super(allows)
      end

      def default_name
        "Permitted"
      end

      def check(criteria)
        crits = criteria.merge(@criteria)
        return LogicalAuthz::check_permitted(crits)
      end
    end

    class ProcPolicy < Policy
      def initialize(allows, &check)
        @check = check
        super(allows)
      end

      def check(criteria)
        @check.call(criteria)
      end
    end
  end
end