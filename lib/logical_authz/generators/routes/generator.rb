module LogicalAuthz
  class RoutesGenerator < LogicalAuthzGenerator
    def add_group_user
      route "post '/group_user' => 'groups_users#create'"
      route "delete '/ungroup_user' => 'groups_users#destroy'"
    end

    def add_permissions
      route "post '/permit' => 'permissions#create'"
      route "delete '/permit' => 'permissions#destroy'"
    end

    def add_groups
      route "resources :groups"
    end

    def default_unauthorized
      route "match '/' => 'home#index', :as => :default_unauthorized"
    end
  end
end
