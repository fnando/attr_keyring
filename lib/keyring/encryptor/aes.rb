module Keyring
  module Encryptor
    module AES
      class Base
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
          encrypted = cipher.update(message) + cipher.final

          Base64.strict_encode64("#{iv}#{encrypted}")
        end

        def self.decrypt(key, message)
          cipher = build_cipher
          cipher.decrypt

          message = Base64.strict_decode64(message)
          iv = message[0...cipher.iv_len]
          encrypted = message[cipher.iv_len..-1]

          cipher.iv = iv
          cipher.key = key
          cipher.update(encrypted) + cipher.final
        end
      end

      class AES128CBC < Base
        def self.cipher_name
          "AES-128-CBC"
        end
      end

      class AES192CBC < Base
        def self.cipher_name
          "AES-192-CBC"
        end
      end

      class AES256CBC < Base
        def self.cipher_name
          "AES-256-CBC"
        end
      end
    end
  end
end
