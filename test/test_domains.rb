require 'test_helper'

class TestDomains < Test::Unit::TestCase
  ALT_DOMAINS = %w(centralfloridacommunityarts.com
                   cfcarts.org
                   centralfloridacommunityarts.org
                   cfcommunityarts.com
                   cfcommunitychoir.com
                   cfcommunityorchestra.com)
  ALL_ALT_DOMAINS = ALT_DOMAINS + ALT_DOMAINS.map { |d| "www.#{d}" }

  def test_http_alternate_domains_respond_with_permanent_redirect
    ALL_ALT_DOMAINS.each do |d|
      uri = URI("http://#{d}")
      response = Net::HTTP.get_response(uri)
      assert_equal "301 Moved Permanently",
                   "#{response.code} #{response.message}",
                   "#{uri} had the wrong response code"
    end
  end

  def test_http_alternate_domains_redirect_to_https_canonical
    ALL_ALT_DOMAINS.each do |d|
      uri = URI("http://#{d}")
      response = Net::HTTP.get_response(uri)
      assert_not_nil response["location"]
      assert_equal URI("https://cfcarts.com"),
                   URI(response["location"]),
                   "#{uri} redirected to the wrong place"
    end
  end

  def test_https_alternate_domains_do_not_listen_on_443
    ALL_ALT_DOMAINS.each do |d|
      uri = URI("https://#{d}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 2
      http.use_ssl = true
      assert_raises(Net::OpenTimeout, "#{uri} did not timeout") do
        http.get(uri)
      end
    end
  end
end
