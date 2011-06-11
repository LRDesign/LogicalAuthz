

class TestController < ApplicationController
  policy do
    allow if_permitted
  end

  def create
    redirect_to :index
  end
end
