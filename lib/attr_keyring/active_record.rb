module AttrKeyring
  module ActiveRecord
    module ClassMethods
      def attr_keyring(keyring, encryptor: Encryptor::AES128CBC)
        self.keyring = Keyring.new(keyring, encryptor)
      end

      def attr_encrypt(*attributes)
        self.encrypted_attributes ||= []
        encrypted_attributes.push(*attributes)

        attributes.each do |attribute|
          define_attr_encrypt_writer(attribute)
          define_attr_encrypt_reader(attribute)
        end
      end

      def define_attr_encrypt_writer(attribute)
        define_method("#{attribute}=") do |value|
          return attr_reset_column(attribute) if value.nil?

          stored_keyring_id = public_send(keyring_column_name)
          keyring_id = stored_keyring_id || self.class.keyring.current_key&.id
          encrypted_value = self.class.keyring.encrypt(value, keyring_id)
          encrypted_value = Base64.strict_encode64(encrypted_value)

          public_send("#{keyring_column_name}=", keyring_id) unless stored_keyring_id
          public_send("encrypted_#{attribute}=", encrypted_value)
          attr_encrypt_digest(attribute, value)
        end
      end

      def define_attr_encrypt_reader(attribute)
        define_method(attribute) do
          encrypted_value = public_send("encrypted_#{attribute}")

          return unless encrypted_value

          encrypted_value = Base64.strict_decode64(encrypted_value)
          keyring_id = public_send(keyring_column_name)
          value = self.class.keyring.decrypt(encrypted_value, keyring_id)
          value
        end
      end
    end

    module InstanceMethods
      private def attr_reset_column(attribute)
        public_send("encrypted_#{attribute}=", nil)
        public_send("#{attribute}_digest=", nil) if respond_to?("#{attribute}_digest=")
        nil
      end

      private def attr_encrypt_digest(attribute, value)
        digest_column = "#{attribute}_digest"
        public_send("#{digest_column}=", Digest::SHA1.hexdigest(value)) if respond_to?(digest_column)
      end

      private def migrate_to_latest_encryption_key
        keyring_id = self.class.keyring.current_key.id

        self.class.encrypted_attributes.each do |attribute|
          value = public_send(attribute)
          next if value.nil?

          encrypted_value = self.class.keyring.encrypt(value, keyring_id)
          encrypted_value = Base64.strict_encode64(encrypted_value)

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
