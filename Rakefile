require 'rubygems'
require 'rake'

task :print_header do
  version_string = `command -v rvm >/dev/null && rvm current`.strip
  version_string = RUBY_DESCRIPTION if !$?.success?
  puts "\n# Starting tests using \e[1m#{version_string}\e[0m\n\n"
end


task :check_dependencies do
  begin
    require "bundler"
  rescue LoadError
    abort "Error: This uses Bundler to manage test dependencies,\n" +
          "but it's not installed. Try `gem install bundler`.\n\n"
  end
  system("bundle check") || abort
end


require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.test_files = FileList["test/**/*.rb"].exclude("test/test_helper.rb",
                                                     "test/helpers/**/*")
  test.libs << "test"
  test.verbose = false
  test.warning = true
end
Rake::Task["test"].enhance ["test:preflight"]

namespace :test do
  desc "Perform all startup checks without running tests"
  task :preflight => [:print_header, :check_dependencies]
end

task :default => :test


desc "Remove build/test/release artifacts"
task :clean do
  paths = %w(.rbx/ coverage/ doc/ Gemfile.lock log/ pkg/)
  paths.each do |path|
    rm_rf File.join(File.dirname(__FILE__), path)
  end
end

desc "Clear macOS DNS cache"
task :flushcache do
  `set -x; sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache`
end
