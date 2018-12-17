require "bundler/inline"
require "stringio"

gemfile do
  source "https://rubygems.org"
  gem "sqlite3"
  gem "activerecord", require: "active_record"
  gem "attr_keyring",
      path: File.expand_path("..", __dir__)
end

ActiveRecord::Base.establish_connection "sqlite3::memory:"

begin
  previous_stdout = $stdout
  $stdout = StringIO.new

  ActiveRecord::Schema.define(version: 0) do
    create_table :users do |t|
      t.binary :encrypted_email, null: false
      t.text :email_digest, null: false
      t.integer :keyring_id, null: false
    end

    add_index :users, :email_digest, unique: true
  end
ensure
  $stdout = previous_stdout
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include AttrKeyring.active_record
end

class User < ApplicationRecord
  attr_keyring "1" => "QSXyoiRDPoJmfkJUZ4hJeQ=="
  attr_encrypt :email

  validates_uniqueness_of :email_digest
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
user = User.find_by_email_digest(Digest::SHA1.hexdigest("jdoe@example.com"))
puts user.email
puts user == john
puts

puts "❌ duplicated email address"
copycat = User.create(email: john.email)
p copycat.errors.to_h
puts

puts "🔑 retrieve latest key from keyring"
puts User.keyring.current_key
