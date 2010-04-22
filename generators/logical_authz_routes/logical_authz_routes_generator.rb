class LogicalAuthzRoutesGenerator < LogicalAuthz::Generator
  def manifest
    record do |manifest|
      manifest.named_route :group_user, '/group_user', :controller => 'groups_users', :action => 'create', :conditions => { :method => :post }
      manifest.named_route :ungroup_user, '/ungroup_user', :controller => 'groups_users', :action => 'destroy', :conditions => { :method => :delete }
      manifest.named_route :permit_page, '/permit', :controller => 'permissions', :action => 'create', :conditions => { :method => :post } 
      manifest.named_route :forbid_page, '/forbid', :controller => 'permissions', :action => 'destroy', :conditions => { :method => :delete }
      manifest.route_resources :groups
    end
  end
end
