# frozen_string_literal: true

#
# Copyright (C) 2025 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

describe "login/canvas/new_login" do
  subject(:rendered_page) do
    render
    Nokogiri::HTML5(response.body)
  end

  let(:account) { Account.default }

  let(:expected_attribute_count) { 17 }

  let(:always_present_attributes) do
    {
      "data-enable-course-catalog" => "true",
      "data-is-preview-mode" => "true",
      "data-terms-required" => "true"
    }
  end

  let(:conditionally_present_attributes) do
    {
      "data-auth-providers" => account.authentication_providers.active.to_json,
      "data-login-handle-name" => "Username",
      "data-login-logo-url" => "custom-logo.png",
      "data-login-logo-text" => "Default Account",
      "data-body-bg-color" => "#ffffff",
      "data-body-bg-image" => "bg.png",
      "data-self-registration-type" => "all",
      "data-recaptcha-key" => "test-recaptcha-key",
      "data-terms-of-use-url" => view.terms_of_use_url,
      "data-privacy-policy-url" => view.privacy_policy_url,
      "data-require-email" => "true",
      "data-password-policy" => account.password_policy.to_json,
      "data-forgot-password-url" => "http://example.com/forgot",
      "data-invalid-login-faq-url" => nil, # defaults to nil
      "data-help-link" => "{\"text\":\"Help\",\"trackCategory\":\"help system\",\"trackLabel\":\"help button\"}",
    }
  end

  before do
    # assign view variables
    assign(:domain_root_account, account)
    assign(:auth_providers, account.authentication_providers.active)
    # stub account methods
    allow(account).to receive_messages(
      enable_course_catalog?: true,
      login_handle_name_with_inference: "Username",
      self_registration_type: "all",
      recaptcha_key: "test-recaptcha-key",
      terms_required?: true,
      require_email_for_registration?: true,
      forgot_password_external_url: "http://example.com/forgot",
      password_policy: { minimum_character_length: 8, require_number_characters: true, require_symbol_characters: true }
    )
    # authentication providers
    mock_auth_providers = [
      { id: 1, auth_type: "apple", display_name: "Apple" },
      { id: 2, auth_type: "google", display_name: "Google" }
    ]
    allow(view).to receive(:auth_providers_with_buttons).and_return(mock_auth_providers)
    assign(:auth_providers, mock_auth_providers)
    # branding values
    allow(view).to receive(:brand_variable).with("ic-brand-Login-logo").and_return("custom-logo.png")
    allow(view).to receive(:brand_variable).with("ic-brand-Login-body-bgd-color").and_return("#ffffff")
    allow(view).to receive(:brand_variable).with("ic-brand-Login-body-bgd-image").and_return("bg.png")
    # external urls
    allow(view).to receive_messages(
      terms_of_use_url: "http://www.canvaslms.com/policies/terms-of-use",
      privacy_policy_url: "http://www.canvaslms.com/policies/privacy-policy",
      params: { previewing_from_themeeditor: "true" }
    )
  end

  it "renders the correct number of data attributes" do
    login_data = rendered_page.at_css("#new_login_data")
    data_attributes = login_data.attributes.keys.grep(/^data-/)
    expect(data_attributes.size).to eq expected_attribute_count
  end

  it "renders the login data div with all expected always-present attributes" do
    login_data = rendered_page.at_css("#new_login_data")
    aggregate_failures "checking always-present attributes" do
      always_present_attributes.each do |attr, expected_value|
        expect(login_data[attr]).to eq(expected_value)
      end
    end
  end

  it "renders only the conditionally present attributes that should exist" do
    login_data = rendered_page.at_css("#new_login_data")
    aggregate_failures "checking conditionally present attributes" do
      conditionally_present_attributes.each do |attr, expected_value|
        if expected_value.nil?
          expect(login_data.attributes).not_to include(attr)
        else
          expect(login_data.attributes).to include(attr)
        end
      end
    end
  end

  context "when forgot password url is not set" do
    before { allow(account).to receive(:forgot_password_external_url).and_return(nil) }

    it "does not include the forgot password url attribute" do
      login_data = rendered_page.at_css("#new_login_data")
      expect(login_data.attributes).not_to include("data-forgot-password-url")
    end
  end

  context "when invalid login faq url is set" do
    before do
      allow(Setting).to receive(:get).with("invalid_login_faq_url", nil).and_return("http://example.com/faq")
    end

    it "includes the invalid login faq url attribute" do
      login_data = rendered_page.at_css("#new_login_data")
      expect(login_data["data-invalid-login-faq-url"]).to eq("http://example.com/faq")
    end
  end

  describe "password policy" do
    context "when set" do
      let(:login_data) { rendered_page.at_css("#new_login_data") }
      let(:policy_json) { JSON.parse(login_data["data-password-policy"]) }

      it "renders only the allowed attributes" do
        expected_policy = {
          "minimum_character_length" => 8,
          "require_number_characters" => true,
          "require_symbol_characters" => true
        }
        expect(policy_json).to eq(expected_policy)
      end

      it "excludes disallowed attributes" do
        allowed_keys = %w[minimum_character_length require_number_characters require_symbol_characters]
        excluded_keys = %w[
          disallow_common_passwords
          max_repeats
          max_sequence
          maximum_character_length
          maximum_login_attempts
        ]
        aggregate_failures "validating included and excluded attributes" do
          expect(policy_json.keys).to match_array(allowed_keys)
          excluded_keys.each { |key| expect(policy_json).not_to have_key(key) }
        end
      end

      it "does not contain unexpected attributes" do
        unexpected_keys = policy_json.keys - %w[minimum_character_length require_number_characters require_symbol_characters]
        expect(unexpected_keys).to be_empty, "Unexpected keys found: #{unexpected_keys.join(", ")}"
      end
    end

    context "when unset" do
      before { allow(account).to receive(:password_policy).and_return(nil) }

      it "does not include the data-password-policy attribute" do
        login_data = rendered_page.at_css("#new_login_data")
        expect(login_data.attributes).not_to include("data-password-policy")
      end
    end

    context "when empty" do
      before { allow(account).to receive(:password_policy).and_return({}) }

      it "does not include the data-password-policy attribute" do
        login_data = rendered_page.at_css("#new_login_data")
        expect(login_data.attributes).not_to include("data-password-policy")
      end
    end
  end
end
