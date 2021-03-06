module LogicalAuthz
  if defined?(:AuthnFacade)
    remove_const(:AuthnFacade)
  end
  module AuthnFacade
    @@current_user = nil

    def self.current_user(controller)
      @@current_user
    end

    def self.current_user=(user)
      @@current_user = user
    end
  end

  module MockAuth
    def logout
      AuthnFacade.current_user = nil
    end

    def login_as(user)
      if <%= user_class %> === user
        AuthnFacade.current_user = user
      else
        AuthnFacade.current_user = Factory(user)
      end
    end
  end
end
