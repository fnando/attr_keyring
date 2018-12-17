module AttrKeyring
  require "attr_keyring/version"
  require "keyring"

  def self.active_record
    require "attr_keyring/active_record"
    ::AttrKeyring::ActiveRecord
  end

  def self.sequel
    require "attr_keyring/sequel"
    ::AttrKeyring::Sequel
  end

  def self.setup(target)
    target.class_eval do
      extend ClassMethods
      include InstanceMethods

      class << self
        attr_accessor :encrypted_attributes
        attr_accessor :keyring
        attr_accessor :keyring_column_name
      end

      self.encrypted_attributes = []
      self.keyring = Keyring.new({})
      self.keyring_column_name = :keyring_id
    end
  end

  module ClassMethods
    def inherited(subclass)
      super

      subclass.encrypted_attributes = encrypted_attributes.dup
      subclass.keyring = keyring
      subclass.keyring_column_name = keyring_column_name
    end

    def attr_keyring(keyring, encryptor: Keyring::Encryptor::AES::AES128CBC)
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
        attr_encrypt_column(attribute, value)
      end
    end

    def define_attr_encrypt_reader(attribute)
      define_method(attribute) do
        attr_decrypt_column(attribute)
      end
    end
  end

  module InstanceMethods
    private def attr_encrypt_column(attribute, value)
      clear_decrypted_column_cache(attribute)
      return reset_encrypted_column(attribute) unless value

      value = value.to_s

      previous_keyring_id = public_send(self.class.keyring_column_name)
      encrypted_value, keyring_id, digest = self.class.keyring.encrypt(value, previous_keyring_id)

      public_send("#{self.class.keyring_column_name}=", keyring_id)
      public_send("encrypted_#{attribute}=", encrypted_value)
      public_send("#{attribute}_digest=", digest) if respond_to?("#{attribute}_digest=")
    end

    private def attr_decrypt_column(attribute)
      cache_name = :"@#{attribute}"
      return instance_variable_get(cache_name) if instance_variable_defined?(cache_name)

      encrypted_value = public_send("encrypted_#{attribute}")
      return unless encrypted_value

      decrypted_value = self.class.keyring.decrypt(encrypted_value, public_send(self.class.keyring_column_name))

      instance_variable_set(cache_name, decrypted_value)
    end

    private def clear_decrypted_column_cache(attribute)
      cache_name = :"@#{attribute}"
      remove_instance_variable(cache_name) if instance_variable_defined?(cache_name)
    end

    private def reset_encrypted_column(attribute)
      public_send("encrypted_#{attribute}=", nil)
      public_send("#{attribute}_digest=", nil) if respond_to?("#{attribute}_digest=")
      nil
    end

    private def migrate_to_latest_encryption_key
      keyring_id = self.class.keyring.current_key.id

      self.class.encrypted_attributes.each do |attribute|
        value = public_send(attribute)
        next if value.nil?

        encrypted_value, _, digest = self.class.keyring.encrypt(value)

        public_send("encrypted_#{attribute}=", encrypted_value)
        public_send("#{attribute}_digest=", digest) if respond_to?("#{attribute}_digest")
      end

      public_send("#{self.class.keyring_column_name}=", keyring_id)
    end
  end
end
