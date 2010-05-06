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

    def authorized_url?(options)
      params = {}
      if Hash === options
        params = options
      else
        path = url_for(options)
        path, querystring = path.split('?')
        params = ActionController::Routing::Routes.recognize_path(path, :method => method)
        querystring.blank? ? params : params.merge(Rack::Utils.parse_query(querystring).symbolize_keys!)
      end
      authorized?(params)
    end

    def authorized_menu(*items)
      authzd = items.find do |item|
        authorized_url? item
      end
      yield(items) unless authzd.nil?
    end

    #Still experimental
    def link_to_if_authorized(name, options = nil, html_options = nil, &block)
      options ||= {}
      html_options ||= {}

      link_to_if(authorized_url?(options), name, options, html_options, &block)
    end
  end
end
