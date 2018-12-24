module Keyring
  require "openssl"
  require "base64"
  require "digest/sha1"

  require "keyring/key"
  require "keyring/encryptor/aes"

  UnknownKey = Class.new(StandardError)
  InvalidSecret = Class.new(StandardError)
  EmptyKeyring = Class.new(StandardError)
  InvalidAuthentication = Class.new(StandardError)

  class Base
    def initialize(keyring, encryptor)
      @encryptor = encryptor
      @keyring = keyring.map do |id, value|
        Key.new(id, value, @encryptor.key_size)
      end
    end

    def current_key
      @keyring.max_by(&:id)
    end

    def [](id)
      raise EmptyKeyring, "keyring doesn't have any keys" if @keyring.empty?

      key = @keyring.find {|k| k.id == id.to_i }
      return key if key

      raise UnknownKey, "key=#{id} is not available on keyring"
    end

    def []=(id, key)
      @keyring << Key.new(id, key, @encryptor.key_size)
    end

    def clear
      @keyring.clear
    end

    def encrypt(message, keyring_id = nil)
      keyring_id ||= current_key&.id
      digest = Digest::SHA1.hexdigest(message)
      key = self[keyring_id]

      [
        @encryptor.encrypt(key, message),
        keyring_id,
        digest
      ]
    end

    def decrypt(message, keyring_id)
      key = self[keyring_id]
      @encryptor.decrypt(key, message)
    end
  end

  def self.new(keyring, encryptor = Encryptor::AES::AES128CBC)
    Base.new(keyring, encryptor)
  end
end
