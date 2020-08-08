require 'test_helper'

class TestSubdomainShortcuts < Test::Unit::TestCase
  include TestHelpers

  def test_mail_domains_have_mail_subdomain_shortcut
    Resolv::DNS.open do |dns|
      MAIL_DOMAINS.each do |d|
        d = "mail.#{d}"
        records = dns.getresources(d, Resolv::DNS::Resource::IN::CNAME)
        assert_equal 1, records.count,
                     "#{d} does not have a CNAME record pointing to Google"
        assert_equal "ghs.googlehosted.com", records.first.name.to_s,
                     "#{d} has a CNAME pointing to #{records.first.name}"
      end
    end
  end

  def test_pm_shortcut_redirects_to_patronmanager_using_302
    uri = URI("http://pm.cfcarts.com")
    response = Net::HTTP.get_response(uri)
    assert_equal "https://cfcarts.lightning.force.com",
                 response["location"],
                 "#{uri} redirected to the wrong place"
    assert_equal "302 Found",
                 "#{response.code} #{response.message}",
                 "#{uri} had the wrong response code"
  end

  def test_pmhelp_shortcut_redirects_to_bitly_url_using_302
    uri = URI("http://pmhelp.cfcarts.com")
    response = Net::HTTP.get_response(uri)
    assert_match %r(^https://bit.ly/[0-9A-Za-z]+$),
                 response["location"],
                 "#{uri} redirected to the wrong place"
    assert_equal "302 Found",
                 "#{response.code} #{response.message}",
                 "#{uri} had the wrong response code"
  end

  def test_pts_shortcut_redirects_to_patronmanager_public_ticketing_site_using_302
    uri = URI("http://pts.cfcarts.com")
    response = Net::HTTP.get_response(uri)
    assert_equal "https://cfcarts.secure.force.com/ticket/",
                 response["location"],
                 "#{uri} redirected to the wrong place"
    assert_equal "302 Found",
                 "#{response.code} #{response.message}",
                 "#{uri} had the wrong response code"
  end
end
