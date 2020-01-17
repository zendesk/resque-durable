require_relative './test_helper'

module Resque::Durable
  class GUIDTest < MiniTest::Unit::TestCase

    describe 'GUID generate' do

      before do
        @hostname     = `hostname`.chomp
        @current_time = Time.now
        @process_id   = Process.pid
      end

      it 'has the hostname, process id and current time' do
        assert_match /#{@hostname}\/#{@process_id}\/#{@current_time.to_i}\/\d+/, GUID.generate
      end

      it 'increments the generation counter' do

        Timecop.freeze(@current_time) do
          first = GUID.generate
          counter = first.split(/\//)[-1].to_i + 1
          assert_equal "#{@hostname}/#{@process_id}/#{@current_time.to_i}/#{counter}", GUID.generate
        end

      end

    end

  end
end
