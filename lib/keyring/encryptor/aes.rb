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

        def self.support_auth_data?
          false
        end

        def self.encrypt(key, message)
          cipher = build_cipher
          cipher.encrypt
          iv = cipher.random_iv
          cipher.iv  = iv
          cipher.key = key.encryption_key
          cipher.auth_data = "" if support_auth_data?
          encrypted = cipher.update(message) + cipher.final
          auth_tag = ""
          auth_tag = cipher.auth_tag if support_auth_data?
          hmac = hmac_digest(key.signing_key, "#{auth_tag}#{iv}#{encrypted}")

          Base64.strict_encode64("#{hmac}#{auth_tag}#{iv}#{encrypted}")
        end

        def self.decrypt(key, message)
          cipher = build_cipher
          iv_size = cipher.random_iv.size
          cipher.decrypt

          message = Base64.strict_decode64(message)

          hmac = message[0...32]

          encrypted_payload = message[32..-1]
          expected_hmac = hmac_digest(key.signing_key, encrypted_payload)

          unless verify_signature(expected_hmac, hmac)
            raise InvalidAuthentication,
                  "Expected HMAC to be " \
                  "#{Base64.strict_encode64(expected_hmac)}; " \
                  "got #{Base64.strict_encode64(hmac)} instead"
          end

          auth_tag = ""
          auth_tag = encrypted_payload[0...16] if support_auth_data?
          iv = encrypted_payload[auth_tag.size...(auth_tag.size + iv_size)]
          encrypted = encrypted_payload[(auth_tag.size + iv_size)..-1]

          cipher.iv = iv
          cipher.key = key.encryption_key

          if support_auth_data?
            cipher.auth_data = ""
            cipher.auth_tag = auth_tag
          end

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

      class AES256GCM < Base
        def self.cipher_name
          "AES-256-GCM"
        end

        def self.support_auth_data?
          true
        end
      end
    end
  end
end
