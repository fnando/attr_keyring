module AttrKeyring
  module ActiveRecord
    module ClassMethods
      def attr_keyring(keyring)
        self.keyring = Keyring.new(keyring)
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
          keyring_id = public_send(keyring_column_name)
          encrypted_value = keyring.encrypt(value, keyring_id)

          public_send("encrypted_#{attribute}=", encrypted_value)
          public_send("#{keyring_column_name}=", keyring_id || keyring.current_key.id) unless keyring_id
        end
      end

      def define_attr_encrypt_reader(attribute)
        define_method(attribute) do
          keyring_id = public_send(keyring_column_name)
          keyring.decrypt(public_send("encrypted_#{attribute}"), keyring_id)
        end
      end
    end

    module InstanceMethods
      private def migrate_to_latest_encryption_key
        keyring_id = keyring.current_key.id

        keyring_attrs.each do |attribute|
          value = public_send(attribute)
          encrypted_value = keyring.encrypt(value, keyring_id)

          public_send("encrypted_#{attribute}=", encrypted_value)

          digest_column = "#{attribute}_digest"
          public_send("#{digest_column}=", Digest::SHA256.hexdigest(value)) if respond_to?(digest_column)
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
