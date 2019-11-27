# frozen_string_literal: true

require "sequel"

module AttrKeyring
  module Sequel
    def self.included(target)
      AttrKeyring.setup(target)

      target.class_eval do
        def before_save
          super
          migrate_to_latest_encryption_key
        end

        def keyring_rotate!
          migrate_to_latest_encryption_key
          save
        end
      end
    end
  end
end
