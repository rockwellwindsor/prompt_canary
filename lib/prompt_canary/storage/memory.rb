# frozen_string_literal: true

module PromptCanary
  module Storage
    class Memory
      def initialize
        @records = []
      end

      def write(record)
        @records << record
      end

      def read_recent(prompt:, version:, limit:)
        @records
          .select { |r| r[:prompt] == prompt && r[:version] == version }
          .last(limit)
      end
    end
  end
end
