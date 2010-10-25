class AuthzController < ApplicationController
  unloadable

  needs_authorization
  admin_authorized
end
