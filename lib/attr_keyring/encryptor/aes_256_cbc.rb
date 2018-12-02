module AttrKeyring
  module Encryptor
    class AES256CBC < AES
      def self.cipher_name
        "AES-256-CBC"
      end
    end
  end
end
