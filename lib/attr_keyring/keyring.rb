module AttrKeyring
  class Keyring
    def initialize(keyring, encryptor = Encryptor::AES128CBC)
      @encryptor = encryptor
      @keyring = keyring.map do |id, value|
        Key.new(id, value, @encryptor.key_size)
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
      @keyring << Key.new(id, value, @encryptor.key_size)
    end

    def clear
      @keyring.clear
    end

    def encrypt(message, keyring_id = current_key.id)
      @encryptor.encrypt(self[keyring_id].value, message)
    end

    def decrypt(message, keyring_id)
      @encryptor.decrypt(self[keyring_id].value, message)
    end
  end
end
