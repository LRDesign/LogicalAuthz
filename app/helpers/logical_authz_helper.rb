module LogicalAuthz
  class << self
    def set_permission_model(klass)
      @perm_model = klass
    end

    def set_group_model(klass)
      @group_model = klass
    end

    def permission_model
      @perm_model || ::Permission rescue nil
    end

    def group_model
      @group_model || ::Group rescue nil
    end
  end

  module Helper
    def authorized?(criteria=nil)
      criteria ||= {}
      criteria = {:controller => controller, :action => action_name, :id => params[:id]}.merge(criteria)
      unless criteria.has_key?(:group) or criteria.has_key?(:user)
        criteria[:user] = AuthnFacade.current_user(self)
      end

      LogicalAuthz.is_authorized?(criteria)
    end 
        
    # returns an array of group names and ids (suitable for select_tag)
    # for which <user> is not a member
    def nonmembered_groups(user)
      (LogicalAuthz::group_model.all - user.groups).map { |g| [ g.name, g.id ] }
    end    

    def groups
      LogicalAuthz::group_model.all.map do |group|
        [group.name, group.id ]
      end
    end

    def controller_pairs
      controllers = ActionController::Routing::possible_controllers
      controllers -= %w{rails/info application authz rails_info}
      controllers.map{|c| [c.classify, c]}
    end

    def authorized_url?(options, html_options = nil)
      html_options ||= {}
      params = {}
      if Hash === options
        params = options
      else
        path = url_for(options)
        path, querystring = path.split('?')
        params = nil
        http_method = html_options[:method] || :get
        begin
          params = ActionController::Routing::Routes.recognize_path(path, :method => http_method)
        rescue ActionController::RoutingError => ex
          return true
        end
        querystring.blank? ? params : params.merge(Rack::Utils.parse_query(querystring).symbolize_keys!)
      end
      authorized?(params)
    end

    def authorized_menu(*items)
      authzd = items.find do |item|
        authorized_url? [*item].last
      end
      yield(items) unless authzd.nil?
    end

    def link_to_if_authorized(name, options = nil, html_options = nil)
      options ||= {}
      html_options ||= {}
      url = options
      if(authorized_url?(url, html_options))
        link_to(name, options, html_options)
      else
        if block_given?
          yield
        else
          name
        end
      end
    end

    def button_to_if_authorized(name, options = {}, html_options = {})
      url = options
      if(authorized_url?(url, html_options))
        button_to(name, options, html_options)
      else
        if block_given?
          yield
        else
          name
        end
      end
    end

    def link_to_remote_if_authorized(name, options = {}, html_options = nil)
      url = options[:url]
      if(authorized_url?(url, html_options))
        link_to_remote(name, options, html_options)
      else
        if block_given?
          yield
        else
          name
        end
      end
    end

    def button_to_remote_if_authorized(name, options = {}, html_options = nil)
      url = options[:url]
      if(authorized_url?(url, html_options))
        button_to_remote(name, options, html_options)
      else
        if block_given?
          yield
        else
          name
        end
      end
    end
  end
end
