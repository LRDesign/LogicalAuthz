require File.expand_path(File.dirname(__FILE__) + '/../support/spec_helper')

describe GroupsController do
  include LogicalAuthz::MockAuth

  def mock_group(stubs={})
    @mock_group ||= mock_model(Group, stubs)
  end

  describe "logging in as non-admin" do
    before(:each) do
      @person = Factory.create(:authz_account)
      login_as(@person)
    end

    it "should redirect away from index with an error message" do
      pending "relocation to host app"
      get :index
      response.should be_redirect
      flash[:error].should_not be_nil
    end
  end

  describe "logged in as admin" do
    before(:each) do
      @person = login_as(Factory.create(:authz_admin))
    end
    
    describe "GET index" do
      it "assigns all groups as @groups" do
        Group.stub!(:all).and_return([mock_group])
        get :index
        controller.should be_authorized
        assigns[:groups].should == [mock_group]
      end
    end
    
    describe "GET show" do
      before(:each) do
        @group = Factory.create(:group, :name => 'foo')
      end

      it "should find and expose the requested group as @group" do
        get :show, :id => @group.id
        assigns[:group].should == @group
      end
    end
   
    describe "POST create" do
      describe "with valid params" do        
        it "creates a new group and assigns it as @group" do
          lambda do 
            post :create, :group => { :name => "foo group" }
          end.should change(Group, :count).by(1)
          assigns[:group].name.should == "foo group"          
        end
        
        it "redirects back" do
          post :create, :group => { :name => "foo group" }
          response.should redirect_to(groups_url)
        end
      end

      describe "with invalid params" do
        it "assigns a newly created but unsaved group as @group" do
          pending
          Group.stub!(:new).and_return(mock_group(:save => false))
          lambda do 
            post :create, :group => {}
          end.should_not change(Group).by(1)
          assigns[:group].should_not be_nil
        end

        it "re-renders the 'new' template" do
          Group.stub!(:new).and_return(mock_group(:save => false))
          post :create, :group => {}
          response.should render_template('new')
        end
      end

    end
  

    describe "DELETE destroy" do
      # create a group for tests to operate on
       before(:each) do
         @group = Factory.create(:group, :name => "foo group")
       end
      
      it "deletes exactly one group" do
        lambda do
          delete :destroy, :id => @group.id
        end.should change(Group, :count).by(-1) 
      end
      it "removes the correct group" do
        Group.find(@group.id).should_not be_nil
        delete :destroy, :id => @group.id
        lambda { Group.find(@group.id) }.should raise_error(ActiveRecord::RecordNotFound)         
      end
    end    
  end
end
