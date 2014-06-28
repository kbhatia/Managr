class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  before_action :require_login

  private
  def require_login
    unless session[:fb_access_token]
      flash[:fb_login_error] = "You must be logged in to access that page."
      redirect_to root_url # halts request cycle
    end
  end

end
