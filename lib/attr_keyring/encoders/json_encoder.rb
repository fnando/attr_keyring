# frozen_string_literal: true

module AttrKeyring
  module Encoders
    module JSONEncoder
      def self.dump(data)
        ::JSON.dump(data)
      end

      def self.parse(data)
        ::JSON.parse(data, symbolize_names: true)
      end
    end
  end
end
