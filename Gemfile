source 'https://rubygems.org'

# Specify your gem's dependencies in elexis-wiki-interface.gemspec
gemspec


gem 'eclipse-plugin', :git => 'https://github.com/ngiger/eclipse-plugin'

group :debuggerx do
if /^2/.match(RUBY_VERSION)
  gem 'pry-byebug'
else
  gem 'pry-debugger'
end
end
