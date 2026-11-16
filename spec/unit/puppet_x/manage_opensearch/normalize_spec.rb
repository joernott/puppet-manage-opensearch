# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/manage_opensearch/normalize'

describe PuppetX::ManageOpensearch::Normalize do
  describe '.index_settings' do
    it 'flattens, prefixes and stringifies settings' do
      expect(described_class.index_settings('number_of_shards' => 1, 'index' => { 'refresh_interval' => '5s' }, 'index.analysis' => { 'x' => [1] })).to eq(
        'index.number_of_shards' => '1', 'index.refresh_interval' => '5s', 'index.analysis.x' => ['1'],
      )
    end

    it 'treats API output and manifest input alike' do
      expect(described_class.index_settings('index' => { 'number_of_shards' => '1' })).to eq(described_class.index_settings(number_of_shards: 1))
    end
  end

  describe '.subset?' do
    let(:stored) { { 'actions' => [{ 'retry' => { 'count' => 3 }, 'rollover' => { 'min_size' => '10gb', 'copy_alias' => false } }] } }

    it { expect(described_class.subset?({ 'actions' => [{ 'rollover' => { 'min_size' => '10gb' } }] }, stored)).to be(true) }
    it { expect(described_class.subset?({ 'actions' => [{ 'rollover' => { 'min_size' => '20gb' } }] }, stored)).to be(false) }
    it { expect(described_class.subset?({ 'actions' => [] }, stored)).to be(false) }
    it { expect(described_class.subset?({ 'actions' => [{ 'retry' => { 'count' => '3' } }] }, stored)).to be(true) }
    it { expect(described_class.subset?({ 'x' => 1 }, nil)).to be(false) }
    it { expect(described_class.subset?(nil, nil)).to be(true) }
  end

  it 'turns lists into sorted sets of strings' do
    expect(described_class.string_set(['b', :a, 'b'])).to eq(%w[a b])
  end

  it 'stringifies keys recursively' do
    expect(described_class.stringify(a: [{ b: :c }])).to eq('a' => [{ 'b' => 'c' }])
  end
end
