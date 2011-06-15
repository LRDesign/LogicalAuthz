module LogicalAuthz
  module PolicyEnforcement
    include Debug

    def criteria_from_url(url, html_options = nil)
      return nil if url.nil?
      uri = URI.parse(url_for(url))
      path = uri.path
      querystring = uri.query
      http_method = (html_options.nil? ? nil : html_options[:method]) || :get
      begin
        params = Rails.application.routes.recognize_path(path, :method => http_method)
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
        #XXX: Shouldn't this be false?
      else
        authorized?(params)
      end
    end

    def authorized?(criteria=nil)
      criteria ||= {}

      laz_debug{"Authorizing: #{inspect_criteria(criteria)}"}

      criteria = {
        :controller => controller_path, 
        :action => action_name, 
        :id => params[:id] 
      }.merge(criteria)
      criteria[:params] = criteria.dup

      unless criteria.has_key?(:group) or criteria.has_key?(:user)
        controller = case self
                     when ActionView::Base
                       self.controller
                     else
                       self #XXX ???
                     end
        criteria[:user] = AuthnFacade.current_user(controller)
      end

      result = LogicalAuthz.is_authorized?(criteria)

      return result
    end 
  end
end
