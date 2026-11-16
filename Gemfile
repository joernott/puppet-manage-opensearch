# frozen_string_literal: true

source ENV['GEM_SOURCE'] || 'https://rubygems.org'

group :test do
  gem 'voxpupuli-test', '~> 15.0', require: false
  gem 'webmock', '~> 3.25', require: false
  # bundled with the OpenVox agent packages, but not a dependency of the gem
  gem 'puppet-resource_api', '>= 1.9', require: false
  # facterdb 4.5 uses jgrep 1.5, which calls JSON.create_id= (removed in json 3)
  gem 'json', '< 3', require: false
end

group :release do
  gem 'voxpupuli-release', '~> 5.0', require: false
end

# OPENVOX_GEM_VERSION selects the OpenVox major in CI, e.g. '~> 8.0' or '~> 9.0'
gem 'openvox', *ENV.fetch('OPENVOX_GEM_VERSION', '>= 8.0, < 10.0').split(',').map(&:strip), require: false
