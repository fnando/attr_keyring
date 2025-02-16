# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

require "bundler/setup"
require "attr_keyring"
require "minitest/utils"
require "minitest/autorun"

require "active_record"
require "attr_vault/cryptor"
require "attr_vault/secret"
require "attr_vault/encryption"

ActiveRecord::Base.establish_connection("postgres:///test")

ActiveRecord::Schema.define(version: 0) do
  drop_table :users if table_exists?(:users)
  drop_table :customers if table_exists?(:customers)
  drop_table :sessions if table_exists?(:sessions)

  create_table :users do |t|
    t.text :encrypted_secret
    t.text :secret_digest
    t.text :encrypted_other_secret
    t.bigint :keyring_id, null: false
  end

  create_table :customers do |t|
    t.text :encrypted_super_secret
    t.bigint :keyring_id, null: false
  end

  create_table :sessions do |t|
    t.timestamps null: false
  end
end

require "sequel"

DB = Sequel.connect("postgres:///test")
Sequel::Model.plugin :timestamps, update_on_create: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
