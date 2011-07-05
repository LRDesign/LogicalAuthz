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

    def debug!
      @debug = true
    end

    def no_debug
      @debug = false
    end

    def debugging?
      defined? @debug and @debug
    end

    def laz_debug
      if block_given? and LogicalAuthz::debugging?
        Rails::logger::debug do
          msg = yield
          String === msg ? msg : msg.inspect
        end
      end
    end
  end

  module Helper
    def laz_debug
      if block_given?
        LogicalAuthz::laz_debug{yield}
      end
    end

    def authorized?(criteria=nil)
      criteria ||= {}

      laz_debug{"Helper authorizing: #{LogicalAuthz.inspect_criteria(criteria)}"}

      criteria = {:controller => controller.class.controller_name, :action => action_name, :id => params[:id]}.merge(criteria)
      unless criteria.has_key?(:group) or criteria.has_key?(:user)
        criteria[:user] = AuthnFacade.current_user(self)
      end

      result = LogicalAuthz.is_authorized?(criteria)

      return result
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

    def criteria_from_url(url, html_options = nil)
      return nil if url.nil?
      uri = URI.parse(url_for(url))
      path = uri.path
      querystring = uri.query
      http_method = (html_options.nil? ? nil : html_options[:method]) || :get
      begin
        params = ActionController::Routing::Routes.recognize_path(path.to_str, :method => http_method)
      rescue ActionController::RoutingError => ex
        Rails.logger.info{"Asked to authorize url: #{html_options.inspect} - couldn't route: #{ex.class.name}: #{ex.message}"}
        return nil
      end
      querystring.blank? ? params : params.merge(Rack::Utils.parse_query(querystring).symbolize_keys!)
    end

    def authorized_url?(options, html_options = nil)
      html_options ||= {}
      params = {}
      if Hash === options
        params = options
      else
        params = criteria_from_url(options)
      end
      if params.nil?
        true #We can't work out where it is, so we have no opinion
      else
        authorized?(params)
      end
    end

    def authorized_menu(*items)
      yield(items) if items.all? do |item|
        authorized_url? [*item].last
      end
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
