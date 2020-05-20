# CFCArts/domain-tests

This is a small suite of unit tests implemented with Ruby's test-unit that
automatically check the redirection/DNS behavior of our domain names.

To run, invoke `rake`.

To run a single test, run something like:

```sh
ruby -Itest test/test_domains.rb -n test_name
```
