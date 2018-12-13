module AttrKeyring
  module Encryptor
    class AES192CBC < AES
      def self.cipher_name
        "AES-192-CBC"
      end
    end
  end
end
