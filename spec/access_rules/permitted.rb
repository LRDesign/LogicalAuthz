class PermittedTestController < ApplicationController
  policy do
    allow if_permitted
    deny always
  end

  def create
    redirect_to :action => :index
  end

  def index
    redirect_to :action => :index
  end

  def show
    redirect_to :action => :index
  end
end

class FoosController < PermittedTestController
end

class BarsController < PermittedTestController
end

class WiresController < PermittedTestController
end

describe "Permitted rule", :type => :controller do
  include LogicalAuthz::MockAuth

  let (:group) { Group.create(:name => "group_#{seq}") }

  let! :controller_permission do
    Permission.create(:role_name => "member", :role_range_id => group.id, 
                      :controller => "foos")
  end

  let! :action_permission do
    Permission.create(:role_name => "member", :role_range_id => group.id, 
                      :controller => "bars", :action => "show")
  end

  let! :id_permission do
    Permission.create(:role_name => "member", :role_range_id => group.id, 
                      :controller => "wires", :action => "show", :subject_id => 1)
  end

  let :authorized_user do
    User.create("user_#{seq}").tap do |user|
      role = Role.create(:authnd_id => user.id, :role_name => "member", :role_range_id => group.id)
    end
  end

  let (:unauthorized_user) do 
    User.create("user_#{seq}")
  end

  before do
    Rails.application.routes.draw do
      resources :foos
      resources :bars
      resources :wires
    end
  end

  after do
    Rails.application.reload_routes!
  end

  describe FoosController do
    describe "unauthenticated" do
      before { logout }

      it "should refuse authorization to :index" do
        get :index
        controller.should be_forbidden
      end

      it "should refuse authorization to :show" do
        get :show, :id => 1
        controller.should be_forbidden
      end
    end

    describe "as an authorized user" do
      before { login_as(authorized_user) }

      it "should be permitted by the controller to :index" do
        get :index
        controller.should be_authorized
      end

      it "should be permitted by the controller to :show" do
        get :show, :id => 1
        controller.should be_authorized
      end
    end

    describe "as an unauthorized user" do
      before { login_as(unauthorized_user) }

      it "should refuse authorization to a controller" do
        get :index
        controller.should be_forbidden
      end
    end
  end


  describe BarsController do
    describe "unauthenticated" do
      before { logout }

      it "should refuse authorization to :index" do
        get :index
        controller.should be_forbidden
      end

      it "should refuse authorization to :show" do
        get :show, :id => 1
        controller.should be_forbidden
      end
    end

    describe "as an authorized user" do
      before { login_as(authorized_user) }

      it "should be authorized by action to :show" do
        get :show, :id => 1
        controller.should be_authorized
        get :show, :id => 2
        controller.should be_authorized
      end

      it "should be forbidden by action to :index" do
        get :index
        controller.should be_forbidden
      end
    end

    describe "as an unauthorized user" do
      before { login_as(unauthorized_user) }

      it "should refuse authorization to a controller" do
        get :show, :id => 1
        controller.should be_forbidden
      end
    end
  end


  describe WiresController do
    describe "unauthenticated" do
      before { logout }

      it "should refuse authorization to :index" do
        get :index
        controller.should be_forbidden
      end

      it "should refuse authorization to :show" do
        get :show, :id => 1
        controller.should be_forbidden
      end
    end

    describe "as an authorized user" do
      before { login_as(authorized_user) }

      it "should be allowed to see records with permissions" do
        get :show, :id => 1
        controller.should be_authorized
      end

      it "should be forbidden records without permissions" do
        get :show, :id => 2
        controller.should be_forbidden
      end
    end

    describe "as an unauthorized user" do
      before { login_as(unauthorized_user) }

      it "should refuse authorization" do
        get :show, :id => 1
        controller.should be_forbidden
      end
    end
  end
end
