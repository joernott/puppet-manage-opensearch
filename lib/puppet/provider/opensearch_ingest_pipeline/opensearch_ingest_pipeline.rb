# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/pipeline_provider'

# Manages ingest pipelines through _ingest/pipeline.
class Puppet::Provider::OpensearchIngestPipeline::OpensearchIngestPipeline < PuppetX::ManageOpensearch::PipelineProvider
  def base_path
    '_ingest/pipeline'
  end

  def attribute_normalizers
    {
      description: :string,
      processors: :hash_value,
      on_failure: :hash_value,
      version: :integer,
    }
  end

  def defaults
    { description: '', processors: [], on_failure: [], version: nil }
  end

  def create(context, name, should)
    raise Puppet::ResourceError, "#{name[:name]}: processors are required to create an ingest pipeline" if should[:processors].nil?

    super
  end
end
