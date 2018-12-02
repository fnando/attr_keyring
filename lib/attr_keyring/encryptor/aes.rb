module AttrKeyring
  module Encryptor
    class AES
      def self.build_cipher
        OpenSSL::Cipher.new(cipher_name)
      end

      def self.key_size
        @key_size ||= build_cipher.key_len
      end

      def self.encrypt(key, message)
        cipher = build_cipher
        cipher.encrypt
        iv = cipher.random_iv
        cipher.iv  = iv
        cipher.key = key
        iv + cipher.update(message) + cipher.final
      end

      def self.decrypt(key, message)
        cipher = build_cipher
        cipher.decrypt
        iv = message[0...cipher.iv_len]
        encrypted = message[cipher.iv_len..-1]
        cipher.iv = iv
        cipher.key = key
        cipher.update(encrypted) + cipher.final
      end
    end
  end
end
