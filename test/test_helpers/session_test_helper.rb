module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  def sign_in_as_platform_operator(operator)
    Current.platform_session = operator.platform_sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:platform_session_id] = Current.platform_session.id
      cookies["platform_session_id"] = cookie_jar[:platform_session_id]
    end
  end

  def sign_out_platform_operator
    Current.platform_session&.destroy!
    cookies.delete("platform_session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
