module AttrKeyring
  class Keyring
    CIPHER_NAME = "AES-128-CBC".freeze

    def initialize(keyring)
      @keyring = keyring.map do |id, value|
        Key.new(id, value)
      end
    end

    def current_key
      @keyring.max_by(&:id)
    end

    def [](id)
      key = @keyring.find {|k| k.id == id.to_i }
      return key if key

      raise UnknownKey, "key=#{id} is not available on keyring"
    end

    def []=(id, value)
      @keyring << Key.new(id, value)
    end

    def clear
      @keyring.clear
    end

    def encrypt(message, keyring_id = current_key.id)
      cipher = OpenSSL::Cipher.new(CIPHER_NAME)
      cipher.encrypt
      iv = cipher.random_iv
      cipher.iv  = iv
      cipher.key = self[keyring_id].value
      iv + cipher.update(message) + cipher.final
    end

    def decrypt(secret, keyring_id)
      decipher = OpenSSL::Cipher.new(CIPHER_NAME)
      decipher.decrypt

      iv = secret[0...decipher.iv_len]
      encrypted = secret[decipher.iv_len..-1]

      decipher.iv = iv
      decipher.key = self[keyring_id].value
      decipher.update(encrypted) + decipher.final
    end
  end
end
