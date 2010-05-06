require 'spec/spec_helper'

class FooController < AuthzController
end

class BarController < AuthzController
end

class WireController < AuthzController
end

describe LogicalAuthz::Helper do
  include LogicalAuthz::MockAuth

  before do
    @group = Factory(:group)
    Factory(:permission, :group => @group, :controller => "foo")
    Factory(:permission, :group => @group, :controller => "bar", :action => "baz")
    Factory(:permission, :group => @group, :controller => "wire", :action => "vinyl", :subject_id => 1)
  end

  it "should refuse authorization to guests" do
    logout
    helper.should_not be_authorized
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
      login_as(:authz_account)
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
