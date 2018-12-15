require "bundler/inline"

gemfile do
  gem "attr_keyring",
      require: "keyring",
      path: File.expand_path("..", __dir__)
end

keyring = Keyring.new("1" => "QSXyoiRDPoJmfkJUZ4hJeQ==")

encrypted, keyring_id, digest = keyring.encrypt("super secret")

puts encrypted
puts keyring_id
puts digest

decrypted = keyring.decrypt(encrypted, keyring_id)
puts decrypted
