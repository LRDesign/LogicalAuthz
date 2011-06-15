class User < ActiveRecord::Base
  include LogicalAuthz::User
end
