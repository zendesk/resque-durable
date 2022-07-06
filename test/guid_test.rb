require_relative './test_helper'

module Resque::Durable
  class GUIDTest < Minitest::Test
    describe 'GUID generate' do
      before do
        @guid = GUID.generate
      end

      it 'valid string value' do
        refute_nil @guid
        assert_equal String, @guid.class
        assert_operator @guid.length, :>, 0
      end

      it 'random values' do
        refute_equal @guid, GUID.generate
      end
    end
  end
end
