![attr_keyring: Simple encryption-at-rest with key rotation support for Ruby.](https://raw.githubusercontent.com/fnando/attr_keyring/master/attr_keyring.png)

<p align="center">
  <a href="https://travis-ci.org/fnando/attr_keyring"><img src="https://travis-ci.org/fnando/attr_keyring.svg" alt="Travis-CI"></a>
  <a href="https://codeclimate.com/github/fnando/attr_keyring"><img src="https://codeclimate.com/github/fnando/attr_keyring/badges/gpa.svg" alt="Code Climate"></a>
  <a href="https://codeclimate.com/github/fnando/attr_keyring/coverage"><img src="https://codeclimate.com/github/fnando/attr_keyring/badges/coverage.svg" alt="Test Coverage"></a>
  <a href="https://rubygems.org/gems/attr_keyring"><img src="https://img.shields.io/gem/v/attr_keyring.svg" alt="Gem"></a>
  <a href="https://rubygems.org/gems/attr_keyring"><img src="https://img.shields.io/gem/dt/attr_keyring.svg" alt="Gem"></a>
</p>

N.B.: attr_keyring is *not* for encrypting passwords--for that, you should use something like [bcrypt](https://github.com/codahale/bcrypt-ruby). It's meant for encrypting sensitive data you will need to access in plain text (e.g. storing OAuth token from users). Passwords do not fall in that category.

This library is heavily inspired by [attr_vault](https://github.com/uhoh-itsmaciek/attr_vault) but it's not a direct port and same keys won't work here without some manual intervention.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "attr_keyring"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install attr_keyring

## Usage

### Configuration

As far as database schema goes:

1. You'll need a column to track the key that was used for encryption; by default it's called `keyring_id`.
2. Every encrypted columns must follow the name `encrypted_<column name>`.
3. Optionally, you can also have a `<column name>_digest` to help with searching (see Lookup section below).

As far as model configuration goes, they're pretty similar, as you can see below:

#### ActiveRecord

From Rails 5+, ActiveRecord models now inherit from `ApplicationRecord` instead. This is how you set it up:

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  include AttrKeyring.active_record
end
```

#### Sequel

Sequel doesn't have an abstract model class (but it could), so you can set up the model class directly like the following:

```ruby
class User < Sequel::Model
  include AttrKeyring.sequel
end
```

### Defining encrypted attributes

To set up your model, you have to define the keyring (set of encryption keys) and the attributes that will be encrypted. Both ActiveRecord and Sequel have the same API, so the examples below work for both ORMs.

```ruby
class User < ApplicationRecord
  attr_keyring ENV["USER_KEYRING"]
  attr_encrypt :twitter_oauth_token, :social_security_number
end
```

The code above will encrypt your columns with the current key. If you're updating a record, then the column will be migrated to the latest key available.

You can use the model as you would normally do.

```ruby
user = User.create(
  email: "john@example.com"
)

user.email
#=> john@example.com

user.keyring_id
#=> 1

user.encrypted_email
#=> WG8Epo0ABz0Z1X5gX7kttc98w9Ei59B5uXGK36Zin9G0VqbxX3naOWOm4RI6w6Uu
```

### Encryption

By default, AES-128-CBC is the algorithm used for encryption. This algorithm uses 16 bytes keys. Using 16-bytes of random data base64-encoded is the recommended way. You can easily generate keys by using the following command:

```console
$ dd if=/dev/urandom bs=16 count=1 2>/dev/null | openssl base64
```

Include the result of this in the `value` section of the key description in the keyring.

You can also use AES-256-CBC, which uses 32-bytes keys. To specify the encryptor when defining the keyring, use `encryptor: AttrKeyring::Encryptor::AES256CBC`.

```ruby
class User < ApplicationRecord
  attr_keyring ENV["USER_KEYRING"],
               encryptor: AttrKeyring::Encryptor::AES256CBC
end
```

#### Key size

- `aes-128-cbc`: 16 bytes.
- `aes-192-cbc`: 24 bytes.
- `aes-256-cbc`: 32 bytes.

#### About the encrypted message

Initialization vectors (IV) should be unpredictable and unique; ideally, they will be cryptographically random. They do not have to be secret: IVs are typically just added to ciphertext messages unencrypted. It may sound contradictory that something has to be unpredictable and unique, but does not have to be secret; it is important to remember that an attacker must not be able to predict ahead of time what a given IV will be.

With that in mind, attr_keyring uses `unencrypted iv + encrypted message` as the value of `encrypted_<column>`. If you're planning to migrate from other encryption mechanisms or read encrypted values from the database without using attr_keyring, make sure you account for this. The IV length can be retrieved by `OpenSSL::Cipher#iv_len`, e.g. `OpenSSL::Cipher.new("AES-128-CBC").iv_len`.

### Keyring

Keys are managed through a keyring--a short JSON document describing your encryption keys. The keyring must be a JSON object mapping numeric ids of the keys to the key values. A keyring must have at least one key. For example:

```json
{
  "1": "QSXyoiRDPoJmfkJUZ4hJeQ==",
  "2": "r6AfOeilPDJomFsiOXLdfQ=="
}
```

The `id` is used to track which key encrypted which piece of data; a key with a larger id is assumed to be newer. The value is the actual bytes of the encryption key.

#### Dynamically loading keyring

If you're using Rails 5.2+, you can use credentials to define your keyring. Your `credentials.yml` must be define like the following:

```yaml
user_keyring:
  1: "QSXyoiRDPoJmfkJUZ4hJeQ=="
  2: "r6AfOeilPDJomFsiOXLdfQ=="
```

Then you can setup your model by using `attr_keyring Rails.application.credentials.user_keyring`.

Other possibilities (e.g. the keyring file is provided by configuration management):

- `attr_keyring YAML.load_file(keyring_file)`
- `attr_keyring JSON.parse(File.read(keyring_file))`.

### Lookup

One tricky aspect of encryption is looking up records by known secret. E.g.,

```ruby
User.where(email: "john@example.com")
```

is trivial with plain text fields, but impossible with the model defined as above.

If a column `<attribute>_digest` exists, then a SHA1 digest from the value will be saved. This will allow you to lookup by that value instead and add unique indexes.

```ruby
User.where(email: Digest::SHA1.hexdigest("john@example.com"))
```

### Key Rotation

Because attr_keyring uses a keyring, with access to multiple keys at once, key rotation is fairly straightforward: if you add a key to the keyring with a higher id than any other key, that key will automatically be used for encryption when records are either created or updated. Any keys that are no longer in use can be safely removed from the keyring.

To check if an existing key with id `123` is still in use, run:

```ruby
# For a large dataset, you may want to index the `keyring_id` column.
User.where(keyring_id: 123).empty?
```

You may not want to wait for records to be updated (e.g. key leaking). In that case, you can rollout a key rotation:

```ruby
User.where(keyring_id: 1234).find_each do |user|
    user.keyring_rotate!
end
```

### What if I don't use ActiveRecord/Sequel?

You can also leverage the encryption mechanism of `attr_keyring` totally decoupled from ActiveRecord/Sequel. First, make sure you load `keyring` instead. Then you can create a keyring to encrypt/decrypt strings, without even touching the database.

```ruby
require "keyring"

keyring = Keyring.new("1" => "QSXyoiRDPoJmfkJUZ4hJeQ==")

encrypted, keyring_id, digest = keyring.encrypt("super secret")

puts encrypted
#=> encrypted: +mOWmIWKMV01nCm076OBnzgPGhWAZqNs8Etaad/0s3I=

puts keyring_id
#=> 1

puts digest
#=> e24fe0dea7f9abe8cbb192702578715079689a3e

decrypted = keyring.decrypt(encrypted, keyring_id)

puts decrypted
#=> super secret
```

### Exchange data with Node.js

If you use Node.js, you may be interested in <https://github.com/fnando/keyring-node>, which is able to read and write messages using the same format.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fnando/attr_keyring. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Icon

Icon made by [Icongeek26](https://www.flaticon.com/authors/icongeek26) from [Flaticon](https://www.flaticon.com/) is licensed by Creative Commons BY 3.0.

## Code of Conduct

Everyone interacting in the attr_keyring project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fnando/attr_keyring/blob/master/CODE_OF_CONDUCT.md).
