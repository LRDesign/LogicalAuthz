class LogicalAuthzRoutesGenerator < LogicalAuthz::Generator
  def manifest
    record do |manifest|
      manifest.route :resources, :groups
      manifest.route :group_user, '/group_user', :controller => 'groups_users', :action => 'create', :conditions => { :method => :post }
      manifest.route :ungroup_user, '/ungroup_user', :controller => 'groups_users', :action => 'destroy', :conditions => { :method => :delete }
      manifest.route :permit_page, '/permit', :controller => 'permissions', :action => 'create', :conditions => { :method => :post } 
      manifest.route :forbid_page, '/forbid', :controller => 'permissions', :action => 'destroy', :conditions => { :method => :delete }
    end
  end
end
