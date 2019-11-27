# frozen_string_literal: true

require "bundler/inline"
require "stringio"

gemfile do
  source "https://rubygems.org"
  gem "sqlite3"
  gem "sequel"
  gem "pry-meta"
  gem "attr_keyring",
      path: File.expand_path("..", __dir__)
end

Sequel.extension :migration

DB = Sequel.sqlite

Sequel.migration do
  up do
    create_table(:users) do
      primary_key :id
      String :encrypted_email, null: false
      String :email_digest, null: false
      Integer :keyring_id, null: false
    end
  end
end.apply(DB, :up)

class User < Sequel::Model
  include AttrKeyring.sequel
  plugin :validation_helpers

  attr_keyring "1" => "QSXyoiRDPoJmfkJUZ4hJeQ=="
  attr_encrypt :email

  def validate
    super
    validates_unique :email_digest
  end
end

john = User.create(email: "john@example.com")

puts "👱‍ attributes"
puts john.email
puts john.email_digest
puts john.encrypted_email
puts john.keyring_id
puts

puts "🔁 rotate key"
User.keyring["2"] = "r6AfOeilPDJomFsiOXLdfQ=="
puts john.keyring_rotate!
puts

puts "👱‍ attributes (after key rotation)"
puts john.email
puts john.email_digest
puts john.encrypted_email
puts john.keyring_id
puts

puts "👨 assign new email"
puts john.update(email: "jdoe@example.com")
puts john.email
puts john.email_digest
puts john.encrypted_email
puts john.keyring_id
puts

puts "🔎 search by email digest"
user = User.first(email_digest: Digest::SHA1.hexdigest("jdoe@example.com"))
puts user.email
puts user == john
puts

puts "❌ duplicated email address"
copycat = User.new(email: john.email)
puts copycat.valid?
p copycat.errors.to_h
puts

puts "🔑 retrieve latest key from keyring"
puts User.keyring.current_key
