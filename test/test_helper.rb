require "bundler/setup"
require "attr_keyring"
require "minitest/utils"
require "minitest/autorun"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define(version: 0) do
  create_table :users do |t|
    t.binary :encrypted_secret
    t.text   :secret_digest
    t.binary :encrypted_other_secret
    t.bigint :keyring_id, null: false
  end
end
