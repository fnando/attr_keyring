# frozen_string_literal: true

require "bundler/inline"

gemfile do
  gem "attr_keyring",
      require: "keyring",
      path: File.expand_path("..", __dir__)
end

gem "attr_keyring"
require "keyring"

keyring = Keyring.new("1" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M=")

# STEP 1: Encrypt message using latest encryption key.
encrypted, keyring_id, digest = keyring.encrypt("super secret")

puts "🔒 #{encrypted}"
puts "🔑 #{keyring_id}"
puts "🔎 #{digest}"

# STEP 2: Decrypted message using encryption key defined by keyring id.
decrypted = keyring.decrypt(encrypted, keyring_id)
puts "✉️ #{decrypted}"
