# frozen_string_literal: true

require 'yaml'

# @summary Converts a hash to a YAML document
#
# Renders the connection file. Using this instead of the stdlib function
# keeps the module free of dependencies.
Puppet::Functions.create_function(:'manage_opensearch::to_yaml') do
  # @param data The data to convert
  # @return [String] The YAML document
  dispatch :to_yaml do
    param 'Hash', :data
  end

  def to_yaml(data)
    data.to_yaml
  end
end
