# CFCArts/domain-tests

This is a small suite of unit tests implemented with Ruby's test-unit that
automatically check the redirection/DNS behavior of our domain names.

## Running the tests

```sh
# All tests, concise output
rake

# All tests, printing each test name
rake TESTOPTS=-v

# Single test
rake TESTOPTS="--name=test_alternate_domains_redirect_http_using_301"

# Single test, invoking ruby directly
ruby -Itest test/test_*.rb --name=test_alternate_domains_redirect_http_using_301
```
