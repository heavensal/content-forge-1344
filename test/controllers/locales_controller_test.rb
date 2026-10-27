# frozen_string_literal: true

require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  test "stores the chosen locale in a cookie and renders that language" do
    patch locale_path, params: { locale: "fr", return_to: new_user_session_path }

    assert_redirected_to new_user_session_path
    assert_equal "fr", cookies[:locale]
    follow_redirect!
    assert_select "h1", text: "Se connecter"
    assert_select "html[lang=fr]"
  end

  test "english is the default when no cookie is set" do
    get new_user_session_path

    assert_select "h1", text: "Sign in"
    assert_select "html[lang=en]"
    assert_select "button", text: "Français", count: 0
  end

  test "the language choice is on the account page" do
    user = User.create!(email: "locale-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Locale")
    sign_in user

    get edit_user_registration_path

    assert_select "h2", text: "Language"
    assert_select "button", text: "Français"
    assert_select "aside button", text: "Français", count: 0
  end

  test "ignores an unknown locale and refuses an external return path" do
    patch locale_path, params: { locale: "de", return_to: "https://evil.example" }

    assert_redirected_to root_path
    assert_nil cookies[:locale]
  end
end
