module Keyring
  require "openssl"
  require "base64"
  require "digest/sha1"

  require "keyring/key"
  require "keyring/encryptor/aes"

  UnknownKey = Class.new(StandardError)
  InvalidSecret = Class.new(StandardError)
  EmptyKeyring = Class.new(StandardError)

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

    def []=(id, value)
      @keyring << Key.new(id, value, @encryptor.key_size)
    end

    def clear
      @keyring.clear
    end

    def encrypt(message, keyring_id = nil)
      keyring_id ||= current_key&.id
      digest = Digest::SHA1.hexdigest(message)

      [
        @encryptor.encrypt(self[keyring_id].value, message),
        keyring_id,
        digest
      ]
    end

    def decrypt(message, keyring_id)
      @encryptor.decrypt(self[keyring_id].value, message)
    end
  end

  def self.new(keyring, encryptor = Encryptor::AES::AES128CBC)
    Base.new(keyring, encryptor)
  end
end
