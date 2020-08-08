require 'rubygems'
require 'bundler'
Bundler.setup

require 'test/unit'
require 'net/http'
require 'resolv'
require 'amazing_print'

module TestHelpers
  ALT_DOMAINS = %w(cfcommunityarts.com
                   centralfloridacommunityarts.com
                   centralfloridacommunityarts.org
                   cfcommunitychoir.com
                   cfcarts.net
                   cfcarts.org)

  MAIL_DOMAINS = %w(cfcarts.com cfcommunityarts.com)

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
end
