module LogicalAuthz
  module Debug
    def laz_debug
      if block_given? and LogicalAuthz::Configuration::debugging?
        Rails::logger::debug do
          msg = yield
          "LAz: " + (String === msg ? msg : msg.inspect)
        end
      end
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
  end
end
