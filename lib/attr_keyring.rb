module AttrKeyring
  require "active_record"
  require "openssl"
  require "digest/sha1"

  require "attr_keyring/version"
  require "attr_keyring/active_record"
  require "attr_keyring/keyring"
  require "attr_keyring/key"
  require "attr_keyring/encryptor/aes"
  require "attr_keyring/encryptor/aes_128_cbc"
  require "attr_keyring/encryptor/aes_192_cbc"
  require "attr_keyring/encryptor/aes_256_cbc"

  UnknownKey = Class.new(StandardError)
  InvalidSecret = Class.new(StandardError)

  def self.included(target)
    target.class_eval do
      extend AttrKeyring::ActiveRecord::ClassMethods
      include AttrKeyring::ActiveRecord::InstanceMethods

      class << self
        attr_accessor :encrypted_attributes
        attr_accessor :keyring

        def inherited(subclass)
          super

          subclass.encrypted_attributes = []
          subclass.keyring = Keyring.new({})
        end
      end

      cattr_accessor :keyring_column_name, default: "keyring_id"
      self.encrypted_attributes = []
      self.keyring = Keyring.new({})

      before_save :migrate_to_latest_encryption_key
    end
  end
end
