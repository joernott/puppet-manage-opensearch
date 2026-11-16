# frozen_string_literal: true

begin
  require 'voxpupuli/test/rake'
rescue LoadError
  # only available in the test group
end

begin
  require 'puppet-strings/tasks'
rescue LoadError
  # only available in the development group
end

begin
  require 'voxpupuli/release/rake_tasks'
rescue LoadError
  # only available in the release group
end
