require 'test_helper'

class TestDomains < Test::Unit::TestCase
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

  def test_alternate_domains_redirect_http_using_301
    domains = with_wwws(ALT_DOMAINS)
    domains.each do |d|
      uri = URI("http://#{d}")
      response = Net::HTTP.get_response(uri)
      assert_equal "301 Moved Permanently",
                   "#{response.code} #{response.message}",
                   "#{uri} had the wrong response code"
    end
  end

  def test_alternate_domains_do_not_listen_on_443
    # Not intended behavior but this is how it works right now
    domains = with_wwws(ALT_DOMAINS)
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

  def test_alternate_domains_redirect_http_to_https_canonical_immediately
    # Intended behavior!
    domains = with_wwws(ALT_DOMAINS)
    domains.each do |d|
      uri = URI("http://#{d}")
      redirected_to = last_location_after_following_redirects(uri, 1)
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

  def test_alternate_domains_do_not_have_mx_records
    alt_domains_without_mx_records = ALT_DOMAINS - MAIL_DOMAINS
    Resolv::DNS.open do |dns|
      alt_domains_without_mx_records.each do |d|
        records = dns.getresources(d, Resolv::DNS::Resource::IN::MX)
        assert_empty records, "#{d} has #{records.count } MX records"
      end
    end
  end

  def test_mail_domains_have_mx_records_for_gmail
    # As specified by Google here https://support.google.com/a/answer/140034
    expected = [
      {priority: 1,  value: "aspmx.l.google.com"},
      {priority: 5,  value: "alt1.aspmx.l.google.com"},
      {priority: 5,  value: "alt2.aspmx.l.google.com"},
      {priority: 10, value: "alt3.aspmx.l.google.com"},
      {priority: 10, value: "alt4.aspmx.l.google.com"}
    ]
    Resolv::DNS.open do |dns|
      MAIL_DOMAINS.each do |d|
        mx_records = dns.getresources(d, Resolv::DNS::Resource::IN::MX).map { |rec|
          {priority: rec.preference, value: rec.exchange.to_s}
        }.sort_by { |rec|
          [rec[:priority], rec[:value]]
        }
        assert_equal expected, mx_records, "#{d} has unexpected MX records"
      end
    end
  end

  def test_mail_domains_have_txt_dkim_records_for_approved_senders
    domains = %w(google._domainkey 2020220560._domainkey).flat_map { |name|
      MAIL_DOMAINS.map { |d| "#{name}.#{d}" }
    }
    # Constant Contact only lets you DKIM one domain =/
    domains.delete("2020220560._domainkey.cfcommunityarts.com")

    Resolv::DNS.open do |dns|
      domains.each do |d|
        records = dns.getresources(d, Resolv::DNS::Resource::IN::TXT)
        records.select! { |r| r.data.start_with?("v=DKIM1;") }
        assert_equal 1, records.count, "#{d} is not a TXT record starting with v=DKIM1;"
        assert_match %r|k=rsa; p=[a-zA-Z0-9+/]+$|, records.first.data,
                     "The rest of the DKIM record at #{d} doesn't follow the expected format"
      end
    end
  end

  def test_mail_domains_have_cnames_for_emma_dkim_system
    # https://support.e2ma.net/s/article/DomainKeys-Identified-Mail-DKIM
    expected_cnames = MAIL_DOMAINS.flat_map { |d|
      [["e2ma-k1._domainkey.#{d}", "e2ma-k1.dkim.e2ma.net"],
       ["e2ma-k2._domainkey.#{d}", "e2ma-k2.dkim.e2ma.net"],
       ["e2ma-k3._domainkey.#{d}", "e2ma-k3.dkim.e2ma.net"]]
    }.to_h

    Resolv::DNS.open do |dns|
      expected_cnames.each do |d, value|
        records = dns.getresources(d, Resolv::DNS::Resource::IN::CNAME)
        assert_equal 1, records.count,
                     "#{d} does not have a CNAME record for Emma's DKIM system"
        assert_equal value, records.first.name.to_s,
                     "#{d} has a CNAME pointing to #{records.first.name}"
      end
    end
  end

  def test_mail_domains_have_cnames_for_salesforce_dkim_system
    # https://help.salesforce.com/articleView?id=emailadmin_create_secure_dkim.htm
    expected_cnames = {
      "salesforce1._domainkey.cfcarts.com"         => "salesforce1.s4zqqr.custdkim.salesforce.com",
      "salesforce2._domainkey.cfcarts.com"         => "salesforce2.3jhvo5.custdkim.salesforce.com",
      "salesforce1._domainkey.cfcommunityarts.com" => "salesforce1.khhamd.custdkim.salesforce.com",
      "salesforce2._domainkey.cfcommunityarts.com" => "salesforce2.33hm7p.custdkim.salesforce.com"
    }

    Resolv::DNS.open do |dns|
      expected_cnames.each do |d, value|
        records = dns.getresources(d, Resolv::DNS::Resource::IN::CNAME)
        assert_equal 1, records.count,
                     "#{d} does not have a CNAME record for Salesforce's DKIM system"
        assert_equal value, records.first.name.to_s,
                     "#{d} has a CNAME pointing to #{records.first.name}"
      end
    end
  end

  def test_mail_domains_mx_records_have_sane_ttls
    # Google suggests 1 hour; longer seems appropriate.
    # Namecheap (or a cache in between) seems to be subtracting jitter from the
    # configured TTLs. Sometimes it's a little, which is fine. But sometimes
    # it's sort of random, from 0 to the expected TTL. Allow 20% for now.
    sanity_cutoff_in_sec = 60 * 60
    sanity_cutoff_in_sec *= 0.8
    Resolv::DNS.open do |dns|
      MAIL_DOMAINS.each do |d|
        records = dns.getresources(d, Resolv::DNS::Resource::IN::MX)
        records.each do |rec|
          assert_compare rec.ttl, ">=", sanity_cutoff_in_sec,
                         "#{d} has an MX record with a TTL of only #{rec.ttl} seconds"
        end
      end
    end
  end

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
end
