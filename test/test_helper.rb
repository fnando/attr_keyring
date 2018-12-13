require "simplecov"
SimpleCov.start

require "bundler/setup"
require "attr_keyring"
require "minitest/utils"
require "minitest/autorun"

ActiveRecord::Base.establish_connection("postgres:///test")

ActiveRecord::Schema.define(version: 0) do
  drop_table :users if table_exists?(:users)
  drop_table :customers if table_exists?(:customers)

  create_table :users do |t|
    t.binary :encrypted_secret
    t.text   :secret_digest
    t.binary :encrypted_other_secret
    t.bigint :keyring_id, null: false
  end

  create_table :customers do |t|
    t.binary :encrypted_super_secret
    t.bigint :keyring_id, null: false
  end
end
