# frozen_string_literal: true

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
          cipher.key = key.encryption_key
          encrypted = cipher.update(message) + cipher.final
          hmac = hmac_digest(key.signing_key, "#{iv}#{encrypted}")

          Base64.strict_encode64("#{hmac}#{iv}#{encrypted}")
        end

        def self.decrypt(key, message)
          cipher = build_cipher
          cipher.decrypt

          message = Base64.strict_decode64(message)

          hmac = message[0...32]
          encrypted_payload = message[32..-1]
          iv = encrypted_payload[0...16]
          encrypted = encrypted_payload[16..-1]

          expected_hmac = hmac_digest(key.signing_key, encrypted_payload)

          unless verify_signature(expected_hmac, hmac)
            raise InvalidAuthentication, "Expected HMAC to be #{Base64.strict_encode64(expected_hmac)}; got #{Base64.strict_encode64(hmac)} instead" # rubocop:disable Metrics/LineLength
          end

          cipher.iv = iv
          cipher.key = key.encryption_key
          cipher.update(encrypted) + cipher.final
        end

        def self.hmac_digest(key, bytes)
          OpenSSL::HMAC.digest("sha256", key, bytes)
        end

        def self.verify_signature(expected, actual)
          expected_bytes = expected.bytes.to_a
          actual_bytes = actual.bytes.to_a

          actual_bytes.inject(0) do |accum, byte|
            accum | byte ^ expected_bytes.shift
          end.zero?
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
