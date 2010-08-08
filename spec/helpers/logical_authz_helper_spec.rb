require File::expand_path(File.join(File.dirname(__FILE__), '..', 'support', 'spec_helper'))

class FooController < AuthzController
end

class BarController < AuthzController
end

class WireController < AuthzController
end

#Needs testing: grants and permissions.
#Specifically: policy on update, grant_alias edit => update - authz works for 
#update & edit

describe LogicalAuthz::Helper do
  include LogicalAuthz::MockAuth

  before do
    @group = Factory(:group)
    @permission_available = Factory(:permission, :group => @group, :controller => "foo")
    @permission_forbidden = Factory(:permission, :group => @group, :controller => "bar", :action => "baz")
    Factory(:permission, :group => @group, :controller => "wire", :action => "vinyl", :subject_id => 1)
  end

## The trouble with all of these is that they depend on the routing for the 
  #app - need to figure out how to add some fake routes just for this test...

  describe "URL helpers:" do
    before do
      user = Factory(:authz_account, :groups => [@group])
      activate_and_login(user)
    end

    #Lifted from ActionController::TestProcess#with_routing
    before :each do
      @real_routes = ActionController::Routing::Routes
      if ActionController::Routing.const_defined? :Routes
        ActionController::Routing.module_eval { remove_const :Routes }
      end

      Factory(:permission, :group => @group, :controller => "permissions", :action => "edit", :subject_id => @permission_available.id)
      Factory(:permission, :group => @group, :controller => "permissions", :action => "delete", :subject_id => @permission_available.id)
      Factory(:permission, :group => @group, :controller => "permissions", :action => "show", :subject_id => @permission_available.id)

      temporary_routes = ActionController::Routing::RouteSet.new
      ActionController::Routing.module_eval { const_set :Routes, temporary_routes }
      temporary_routes.draw do |map|
        map.resources :foo
        map.resources :bar
        map.resources :wire
        map.resources :permissions
      end
    end

    after :each do
      if ActionController::Routing.const_defined? :Routes
        ActionController::Routing.module_eval { remove_const :Routes }
      end
      ActionController::Routing.const_set(:Routes, @real_routes) if @real_routes
    end

    describe "authorized_url?" do
      it "should permit {:controller => 'foo', :action => 'show', :id => #}" do
        helper.authorized_url?({:controller => 'foo', :action => 'show', :id => 1}).should be_true
      end

      it "should forbid {:controller => 'bar', :action => 'destroy', :id => 1}" do
        helper.authorized_url?({:controller => 'bar', :action => 'destroy', :id => 1}).should be_false
      end

      it "should permit edit_foo_path(@foo.id)" do 
        helper.authorized_url?(edit_foo_path(1)).should be_true
      end

      it "should permit foo_path(@foo.id), :method => :put" do 
        helper.authorized_url?(foo_path(1), :method => :put).should be_true
      end

      it "should forbid edit_bar_path(@bar.id)" do
        helper.authorized_url?(edit_bar_path(1)).should be_false
      end

      it "should permit edit_foo_url(@foo.id)" do 
        helper.authorized_url?(edit_foo_path(1)).should be_true
      end

      it "should forbid edit_bar_url(@bar.id)" do
        helper.authorized_url?(edit_bar_path(1)).should be_false
      end

      it "should permit @foo" do 
        helper.authorized_url?(@permission_available).should be_true
      end

      it "should forbid @bar" do
        helper.authorized_url?(@permission_forbidden).should be_false
      end

      it "should permit http://elsewhere.com/something_boring?with_fries=1" do 
        helper.authorized_url?("http://elsewhere.com/something_boring?with_fries=1").should be_true
      end
    end

    describe "link_to_if_authorized" do
      it "should emit an <A> tag if authorized" do
        foo_link = helper.link_to_if_authorized("Foo", @permission_available, :method => :delete)
        foo_link.should =~ /^<a/
          foo_link.should == helper.link_to("Foo", @permission_available, :method => :delete)
      end

      it "should emit just the name if forbidden" do 
        helper.link_to_if_authorized("Client", @permission_forbidden).should == "Client"
      end
    end

    it "button_to_if_authorized should should work analogously to button_to" do
      args = ["Delete Project", @permission_available, {:method => :delete}]
      link = helper.button_to_if_authorized(*args.dup)
      link.should == helper.button_to(*args.dup)
      link.should =~ /^<form/
    end

    it "link_to_remote_if_authorized should work analogously to link_to_remote" do
      args = ["Delete Project", {:url => @permission_available}, {:method => :delete}]
      link = helper.link_to_remote_if_authorized(*args.dup)
      link.should == helper.link_to_remote(*args.dup)
      link.should =~ /^<a href/
    end

    it "button_to_remote_if_authorized should work analogously to button_to_remote" do
      args = ["Delete Project", {:url => @permission_available}, {:method => :delete}]
      link = helper.button_to_remote_if_authorized(*args.dup)
      link.should == helper.button_to_remote(*args.dup)
      link.should =~ /^<input/
    end
  end

  describe "authorized" do
    it "should refuse authorization to guests" do
      logout
      helper.authorized?(:controller => "foo",
                         :action => :nerf,
                         :id => 7).should == false
    end

    describe "should recognize authorized users" do
      before do
        user = Factory(:authz_account, :groups => [@group])
        login_as(user)
      end

      it "on a controller level" do
        helper.authorized?(:controller => "foo",
                           :action => "nerf",
                           :id => 7).should == true
      end

      it "on an action level" do
        helper.authorized?(:controller => "bar",
                           :action => "baz",
                           :id => 23).should == true
      end

      it "not on the wrong action level" do
        helper.authorized?(:controller => "bar",
                           :action => "bat",
                           :id => 23).should == false
      end

      it "on a record level" do
        helper.authorized?(:controller => "wire",
                           :action => "vinyl",
                           :id => 1).should == true
      end

      it "not on the wrong record level" do
        helper.authorized?(:controller => "wire",
                           :action => "vinyl",
                           :id => 2).should == false
      end
    end

    describe "should refuse unauthorized users" do
      before do
        user = Factory(:authz_account)
        login_as(user)
      end

      it "on a controller level" do
        helper.authorized?(:controller => "foo",
                           :action => "nerf",
                           :id => 7).should == false
      end

      it "on an action level" do
        helper.authorized?(:controller => "bar",
                           :action => "baz",
                           :id => 23).should == false
      end

      it "on a record level" do
        helper.authorized?(:controller => "wire",
                           :action => "vinyl",
                           :id => 1).should == false
      end
    end
  end
end
