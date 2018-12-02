module AttrKeyring
  require "active_record"
  require "openssl"

  require "attr_keyring/version"
  require "attr_keyring/active_record"
  require "attr_keyring/keyring"
  require "attr_keyring/key"
  require "attr_keyring/encryptor/aes"
  require "attr_keyring/encryptor/aes_128_cbc"
  require "attr_keyring/encryptor/aes_256_cbc"

  UnknownKey = Class.new(StandardError)
  InvalidSecret = Class.new(StandardError)

  def self.included(target)
    target.class_eval do
      extend AttrKeyring::ActiveRecord::ClassMethods
      include AttrKeyring::ActiveRecord::InstanceMethods

      cattr_accessor :keyring, default: Keyring.new({})
      cattr_accessor :keyring_column_name, default: "keyring_id"
      cattr_accessor :keyring_attrs, default: []

      before_save :migrate_to_latest_encryption_key
    end
  end
end
