require 'logical_authz/configuration'
require 'logical_authz/policy_enforcement'

module LogicalAuthzHelper
  include LogicalAuthz::PolicyEnforcement

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
      return link_to(name, options, html_options)
    else
      if block_given?
        yield
      end
      return ""
    end
  end

  def button_to_if_authorized(name, options = {}, html_options = {})
    url = options
    if(authorized_url?(url, html_options))
      return button_to(name, options, html_options)
    else
      if block_given?
        yield
      end
      return ""
    end
  end
end
