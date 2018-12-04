module AttrKeyring
  module ActiveRecord
    module ClassMethods
      def attr_keyring(keyring, encryptor: Encryptor::AES128CBC)
        self.keyring = Keyring.new(keyring, encryptor)
      end

      def attr_encrypt(*attributes)
        keyring_attrs.push(*attributes)

        attributes.each do |attribute|
          define_attr_encrypt_writer(attribute)
          define_attr_encrypt_reader(attribute)
        end
      end

      def define_attr_encrypt_writer(attribute)
        define_method("#{attribute}=") do |value|
          return attr_reset_column(attribute) if value.nil?

          stored_keyring_id = public_send(keyring_column_name)
          keyring_id = stored_keyring_id || keyring.current_key&.id
          encrypted_value = keyring.encrypt(value, keyring_id)

          public_send("#{keyring_column_name}=", keyring_id) unless stored_keyring_id
          public_send("encrypted_#{attribute}=", encrypted_value)
          attr_encrypt_digest(attribute, value)
        end
      end

      def define_attr_encrypt_reader(attribute)
        define_method(attribute) do
          encrypted_value = public_send("encrypted_#{attribute}")

          return unless encrypted_value

          keyring_id = public_send(keyring_column_name)
          keyring.decrypt(encrypted_value, keyring_id)
        end
      end
    end

    module InstanceMethods
      private def attr_reset_column(attribute)
        public_send("encrypted_#{attribute}=", nil)
        public_send("#{attribute}_digest=", nil)
        nil
      end

      private def attr_encrypt_digest(attribute, value)
        digest_column = "#{attribute}_digest"
        public_send("#{digest_column}=", Digest::SHA1.hexdigest(value)) if respond_to?(digest_column)
      end

      private def migrate_to_latest_encryption_key
        keyring_id = keyring.current_key.id

        keyring_attrs.each do |attribute|
          value = public_send(attribute)
          encrypted_value = keyring.encrypt(value, keyring_id)

          public_send("encrypted_#{attribute}=", encrypted_value)
          attr_encrypt_digest(attribute, value)
        end

        public_send("#{keyring_column_name}=", keyring_id)
      end

      def keyring_rotate!
        migrate_to_latest_encryption_key
        save! if changed?
      end
    end
  end
end
