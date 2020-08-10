require 'test_helper'

class TestVerificationRecords < Test::Unit::TestCase
  include TestHelpers

  def test_web_domain_has_txt_record_for_google_site_verification
    # This record should stay in place to maintain access to Search Console
    d = "cfcarts.com"
    Resolv::DNS.open do |dns|
      records = dns.getresources(d, Resolv::DNS::Resource::IN::TXT)
      records.select! { |r| r.data.start_with?("google-site-verification=") }
      assert_equal 1, records.count, "#{d} should have one TXT record starting with google-site-verification="
      assert_equal "google-site-verification=uC1mQSG_30FTjLx8rMy_ncs_Mq-yqkJwvoSAtG60uVA",
                   records.first.data,
                   "The Google Site Verification TXT record doesn't have the right verification hash"
    end
  end
end
