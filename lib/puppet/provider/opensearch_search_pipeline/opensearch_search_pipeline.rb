# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/pipeline_provider'

# Manages search pipelines through _search/pipeline.
class Puppet::Provider::OpensearchSearchPipeline::OpensearchSearchPipeline < PuppetX::ManageOpensearch::PipelineProvider
  def base_path
    '_search/pipeline'
  end

  def attribute_normalizers
    {
      description: :string,
      request_processors: :hash_value,
      response_processors: :hash_value,
      phase_results_processors: :hash_value,
      version: :integer,
    }
  end

  def defaults
    { description: '', request_processors: [], response_processors: [], phase_results_processors: [], version: nil }
  end
end
