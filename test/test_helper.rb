require 'bundler/setup'

require 'resque/durable'
require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/setup'
require 'timecop'

require 'active_record'
require 'logger'
database_config = YAML.load_file(File.join(File.dirname(__FILE__), 'database.yml'))
ActiveRecord::Schema.verbose = false
ActiveRecord::Base.establish_connection(database_config['test'])
ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.logger = Logger.new('/dev/null')

require './test/schema'

I18n.enforce_available_locales = true

MiniTest::Unit::TestCase.class_eval do
  def setup
    Resque::Durable::QueueAudit.delete_all
  end
  def teardown
    Mocha::Mockery.instance.teardown
    Mocha::Mockery.reset_instance
  end
end

module Resque
  module Durable

    class MailQueue

      class << self
        def data=(data)
          @data = data
        end

        def data
          @data
        end

        def pop
          @data.pop
        end

        def enqueue(*payload)
          @data.push(payload)
        end
      end

    end

    class MailQueueJob
      extend Resque::Durable
      @queue = :test_queue
      def self.perform(one, two, audit)
        raise Exception, "Failing Job!" if self.fail
      end

      cattr_accessor :fail
    end

    class BackgroundHeartbeatTestJob
      extend Resque::Durable
      self.background_heartbeat_interval = 0.1
      @queue = :test_queue

      def self.perform(travel_to, audit)
        Timecop.travel(Time.parse travel_to) do
          sleep 0.2
        end
      end
    end
  end
end

def work_queue(name)
  worker = Resque::Worker.new(name)
  worker.process
end

