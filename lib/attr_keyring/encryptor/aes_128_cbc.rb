module AttrKeyring
  module Encryptor
    class AES128CBC < AES
      def self.cipher_name
        "AES-128-CBC"
      end
    end
  end
end
