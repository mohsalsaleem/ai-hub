module Platform
  class BaseController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :set_current_organization

    include PlatformAuthentication
  end
end
