module LogicalAuthz
  module AccessControl
    class PolicyDefinitionError < ::Exception; end

    class Builder
      def initialize
        @list = @before = []
        @after = []
      end

      def define(&block)
        instance_eval(&block)
      end

      def resolve_rule(rule)
        case rule
        when Policy #This is the important case, actually
        when Symbol, String
          klass = Policy.names[rule.to_sym]
          raise "Policy name #{rule} not found in #{Policy.names.keys.inspect}" if klass.nil?
          Rails.logger.debug { "Using deprecated string/symbol policy naming: #{rule.inspect}" }
          rule = klass.new
        when Class
          rule = rule.new
          unless rule.responds_to?(:check)
            raise "Policy classes must respond to #check"
          end
        when Proc
          rule = ProcPolicy.new(&rule)
        else
          raise "Authorization Rules have to be Policy objects, a Policy class or a proc"
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
        IfAllows.new(&block)
      end

      def if_denied(&block)
        IfDenies.new(&block)
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

    class Policy
      def initialize
        @decision = false
        @name = default_name
      end

      def laz_debug
        LogicalAuthz::laz_debug{yield} if block_given?
      end

      attr_accessor :name, :decision

      def default_name
        "Unknown Rule"
      end

      def check(criteria)
        raise NotImplementedException
      end

      def evaluate(criteria)
        laz_debug{"Rule being examined: #{self.inspect}"}
        if check(criteria) == true
          laz_debug{"Rule: #@name triggered - authorization allowed: #@decision"}
          return @decision
        else
          return nil
        end
      rescue Object => ex
        laz_debug{ "Exception raised checking rule \"#@name\": #{ex.class.name}: #{ex.message}" }
        return nil
      end

      class << self
        def names
          @names ||= {}
        end

        def register(name)
          Policy.names[name.to_sym] = self
          Policy.names["if_#{name}".to_sym] = self

          AccessControl::Builder.define_method(name) { self.new }
          AccessControl::Builder.define_method("if_#{name}") { self.new }
        end
      end
    end

    #The policy rule of last resort
    class ProcPolicy < Policy
      def initialize(&check)
        @check = check
        super()
      end

      def check(criteria)
        @check.call(criteria)
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

    class Reversed < Policy
      def initialize(other)
        @other = other
        super()
      end

      def default_name
        "Unless: #{@other.default_name}"
      end

      def check(criteria)
        !@other.check(criteria)
      end
    end

    class RemappedCriteria < Policy
      def initialize(other, &block)
        @other = other
        @block = block
        super()
      end

      def default_name
        "Remapped: #{@other.default_name}"
      end

      def check(criteria)
        new_criteria = @block.call(criteria.dup)
        @other.check(new_criteria)
      end
    end

    class SubPolicy < Policy
      def initialize(&block)
        super()
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
      def default_name
        "If allowed by..."
      end

      def match_policy(policy)
        policy == true
      end
    end

    class IfDenies < SubPolicy
      def default_name
        "If denied by..."
      end

      def match_policy(policy)
        policy == false
      end
    end

    class Administrator < Policy
      register :admin

      def default_name
        "Admins"
      end

      def check(criteria)
        return criteria[:group].include?(Group.admin_group)
      end
    end

    class Authenticated < Policy
      register :authenticated

      def default_name
        "Authenicated"
      end

      def check(criteria)
        criteria[:user] != nil
      end
    end

    class Authorized < Policy
      register :authorized

      def default_name
        "When Authorized"
      end

      #This probably needs some assurance that it cannot loop
      def check(criteria)
        criteria[:authorization_depth] ||= 0
        criteria[:authorization_depth] += 1

        unless criteria[:authorization_depth] > 10
          raise "Authorization recursion limit reached" 
        end

        LogicalAuthz.is_authorized?(criteria)
      end
    end

    class Owner < Policy
      register :owner

      def initialize(&map_owner)
        @mapper = map_owner
        super()
      end

      def default_name
        "Related"
      end

      def check(criteria)
        return false unless criteria.has_key?(:user) and criteria.has_key?(:id)
        unless @mapper.nil?
          begin
            @mapper.call(criteria[:user], criteria[:id].to_i)
          rescue Object => ex
            return false
          end
        else
          criteria[:user].id == criteria[:id].to_i
        end
      end
    end

    class Permitted < Policy
      register :permitted

      def initialize(specific_criteria = {})
        @criteria = specific_criteria
        super()
      end

      def default_name
        "Permitted"
      end

      def check(criteria)
        crits = criteria.merge(@criteria)
        return LogicalAuthz::check_permitted(crits)
      end
    end
  end
end
