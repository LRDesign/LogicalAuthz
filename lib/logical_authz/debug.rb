module LogicalAuthz
  module Debug
    def laz_debug
      if block_given? and LogicalAuthz::Configuration::debugging?
        Rails::logger::debug do
          msg = yield
          String === msg ? msg : msg.inspect
        end
      end
    end
  end
end
