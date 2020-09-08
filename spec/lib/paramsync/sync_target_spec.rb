# This software is public domain. No rights are reserved. See LICENSE for more information.

require 'spec_helper'

RSpec.describe Paramsync::SyncTarget do
  describe '#local_items' do
    context 'using a yml file with deeply nested hashes' do
      let(:tgt) {
        Paramsync::SyncTarget.new(
          base_dir: FIXTURE_DIR,
          config: {
            'type'   => 'file',
            'path'   => "nested_hashes.yml",
            'prefix' => 'config/nested'
          },
          consul_url: Paramsync::Config::DEFAULT_CONSUL_URL,
          token_source: Paramsync::PassiveTokenSource.new,
        )
      }

      it 'must flatten the nested hashes' do
        items = tgt.local_items
        expect(items.values).to all be_a String

        expect(items).to include({'one_key' => 'foo'})
        expect(items).to include({'nested_hash/two_key' => 'bar'})
        expect(items).to include({'nested_hash/nested_hash/three_key' => 'baz'})
        expect(items).to include({'nested_hash/nested_hash' => 'wat'})
      end
    end
  end

  context 'using a yml file with deeply nested hashes and erb' do
    let(:tgt) {
      Paramsync::SyncTarget.new(
        base_dir: FIXTURE_DIR,
        config: {
          'type'   => 'file',
          'path'   => "nested_hashes.erb.yml",
          'prefix' => 'config/nested',
          'erb_enabled' => true
        },
        consul_url: Paramsync::Config::DEFAULT_CONSUL_URL,
        token_source: Paramsync::PassiveTokenSource.new,
      )
    }

    it 'must flatten the nested hashes' do
      items = tgt.local_items
      expect(items.values).to all be_a String

      expect(items).to include({'one_key' => 'foo'})
      expect(items).to include({'nested_hash/two_key' => 'bar'})
      expect(items).to include({'nested_hash/nested_hash/three_key' => 'baz'})
      expect(items).to include({'nested_hash/nested_hash/with_erb' => '123'})
      expect(items).to include({'nested_hash/nested_hash' => 'wat'})
    end
  end
end
