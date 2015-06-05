require "bundler"
Bundler.setup(:default, :development)

unless RUBY_PLATFORM =~ /java/
  begin
    require 'pry'
  rescue Exception
    # ignore it
  end
  require "simplecov"
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  SimpleCov.start do
      add_filter "spec"
  end
end

require "rspec"

