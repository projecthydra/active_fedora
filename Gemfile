source "https://rubygems.org"

# Bundler will rely on active-fedora.gemspec for dependency information.

gemspec path: File.expand_path('..', __FILE__)

gem 'byebug' unless ENV['TRAVIS']
gem 'pry-byebug' unless ENV['CI']

gem 'activemodel', ENV['RAILS_VERSION'] if ENV['RAILS_VERSION']
gem 'active-triples', github: 'ActiveTriples/ActiveTriples', branch: :develop

group :test do
  gem 'simplecov', require: false
  gem 'coveralls', require: false
end

gem 'jruby-openssl', platform: :jruby
