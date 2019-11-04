require 'test_helper'

class TestDomains < Test::Unit::TestCase
  ALT_DOMAINS_WITH_DNS_MANAGED_BY_REGISTRAR = %w(centralfloridacommunityarts.com
                                                 centralfloridacommunityarts.org
                                                 cfcommunitychoir.com
                                                 cfcarts.net
                                                 cfcarts.org)
  ALT_DOMAINS_WITH_DNS_MANAGED_BY_WEBHOST   = %w(cfcommunityarts.com)

  ALL_ALT_DOMAINS = ALT_DOMAINS_WITH_DNS_MANAGED_BY_REGISTRAR +
                    ALT_DOMAINS_WITH_DNS_MANAGED_BY_WEBHOST

  CANONICAL_URI = URI("https://cfcarts.com")

  def with_wwws(domain_list)
    domain_list + domain_list.map { |d| "www.#{d}" }
  end

  def last_location_after_following_redirects(uri, limit = 5)
    raise 'Too many redirects' if limit < 0

    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPRedirection)
      last_location_after_following_redirects(URI(response["location"]), limit - 1)
    else
      uri
    end
  end

  def test_all_alternate_domains_redirect_http_using_301
    domains = with_wwws(ALL_ALT_DOMAINS)
    domains.each do |d|
      uri = URI("http://#{d}")
      response = Net::HTTP.get_response(uri)
      assert_equal "301 Moved Permanently",
                   "#{response.code} #{response.message}",
                   "#{uri} had the wrong response code"
    end
  end

  def test_registrar_alternate_domains_do_not_listen_on_443
    # Not intended behavior but this is how it works right now
    domains = with_wwws(ALT_DOMAINS_WITH_DNS_MANAGED_BY_REGISTRAR)
    domains.each do |d|
      uri = URI("https://#{d}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 2
      http.use_ssl = true
      expected_exceptions = [Net::OpenTimeout, Errno::ECONNREFUSED]
      assert_raises(*expected_exceptions, "#{uri} responded but shouldn't have") do
        http.get(uri)
      end
    end
  end

  def test_registrar_alternate_domains_redirect_http_to_https_canonical_immediately
    # Intended behavior!
    domains = with_wwws(ALT_DOMAINS_WITH_DNS_MANAGED_BY_REGISTRAR)
    domains.each do |d|
      uri = URI("http://#{d}")
      redirected_to = last_location_after_following_redirects(uri, 1)
      assert_equal CANONICAL_URI,
                   redirected_to,
                   "#{uri} redirected to the wrong place"
    end
  end

  def test_webhost_alternate_domains_redirect_http_and_https_to_https_canonical_eventually
    # Almost intended behavior! Should happen immediately
    domains = with_wwws(ALT_DOMAINS_WITH_DNS_MANAGED_BY_WEBHOST)
    uris = domains.map { |d| [URI("http://#{d}"), URI("https://#{d}")] }.flatten
    uris.each do |uri|
      redirected_to = last_location_after_following_redirects(uri, 5)
      assert_equal CANONICAL_URI,
                   redirected_to,
                   "#{uri} redirected to the wrong place"
    end
  end

  def test_www_cfcarts_com_redirects_to_https_canonical_without_www
    # Intended behavior!
    uris = [URI("http://www.cfcarts.com"), URI("https://www.cfcarts.com")]
    uris.each do |uri|
      response = Net::HTTP.get_response(uri)
      assert_equal "301 Moved Permanently",
                   "#{response.code} #{response.message}",
                   "#{uri} had the wrong response code"
      assert_not_nil response["location"]
      assert_equal CANONICAL_URI,
                   URI(response["location"]),
                   "#{uri} redirected to the wrong place"
    end
  end
end
