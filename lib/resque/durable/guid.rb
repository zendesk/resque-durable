require 'uuidtools'

module Resque
  module Durable
    module GUID
      def self.generate
        UUIDTools::UUID.random_create.to_s
      end
    end
  end
end
