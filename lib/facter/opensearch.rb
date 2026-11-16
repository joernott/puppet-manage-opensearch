# frozen_string_literal: true

# Structured fact describing the OpenSearch cluster this node belongs to.
# Only present where the class manage_opensearch wrote its connection file.
require_relative '../puppet_x/manage_opensearch/facts'

Facter.add(:opensearch) do
  confine { PuppetX::ManageOpensearch::Config.exist? }

  setcode do
    PuppetX::ManageOpensearch::Facts.collect
  end
end
