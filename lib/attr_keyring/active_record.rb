require "active_record"

module AttrKeyring
  module ActiveRecord
    def self.included(target)
      AttrKeyring.setup(target)

      target.class_eval do
        before_save :migrate_to_latest_encryption_key

        def keyring_rotate!
          migrate_to_latest_encryption_key
          save!
        end
      end

      target.prepend(
        Module.new do
          def reload(options = nil)
            instance = super

            self.class.encrypted_attributes.each do |attribute|
              clear_decrypted_column_cache(attribute)
            end

            instance
          end
        end
      )
    end
  end
end
