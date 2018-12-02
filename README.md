![attr_keyring: Simple encryption-at-rest with key rotation support for ActiveRecord.](https://raw.githubusercontent.com/fnando/attr_keyring/master/attr_keyring.png)

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

### Encryption

The key should be 16 bytes of random data, base64-encoded. A simple way to generate that is:

```console
$ dd if=/dev/urandom bs=16 count=1 2>/dev/null | openssl base64
```

Include the result of this in the `value` section of the key description in the keyring.

### Keyring

Keys are managed through a keyring--a short JSON document describing your encryption keys. The keyring must be a JSON object mapping numeric ids of the keys to the key values. A keyring must have at least one key. For example:

```json
{
  "1": "PV8+EHgJlHfsVVVstJHgEo+3OCSn4iJDzqJs55U650Q=",
  "2": "0HyJ15am4haRsCyiFCxDdlKwl3G5yPNKTUbadpaIfPI="
}
```

The `id` is used to track which key encrypted which piece of data; a key with a larger id is assumed to be newer. The value is the actual bytes of the encryption key.

#### Dynamically loading keyring

If you're using Rails 5.2+, you can use credentials to define your keyring. Your `credentials.yml` must be define like the following:

```yaml
user_keyring:
  1: "PV8+EHgJlHfsVVVstJHgEo+3OCSn4iJDzqJs55U650Q="
  2: "0HyJ15am4haRsCyiFCxDdlKwl3G5yPNKTUbadpaIfPI="
```

Then you can setup your model by using `attr_keyring Rails.application.credentials.user_keyring`.

Other possibilities (e.g. the keyring file is provided by configuration management):

- `attr_keyring YAML.load_file(keyring_file)`
- `attr_keyring JSON.parse(File.read(keyring_file))`.

### Model Setup

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include AttrKeyring
end

class User < ApplicationRecord
  attr_keyring ENV["APP_KEYRING"]
  attr_encrypt :twitter_oauth_token
end
```

The code above will encrypt your columns with the current key. If you're updating a record, then the column will be migrated to the latest key available.

### Lookup

One tricky aspect of encryption is looking up records by known secret. E.g.,

```ruby
User.where(twitter_oauth_token: "241F596D-79FF-4C08-921A-A19E533B4F52")
```

is trivial with plain text fields, but impossible with the model defined as above.

If add a column `<attribute>_digest`, a SHA256 value will be saved, allowing you to lookup by that value instead.

```ruby
User.where(twitter_oauth_token_digest: Digest::SHA256.hexdigest("241F596D-79FF-4C08-921A-A19E533B4F52"))
```

### Key Rotation

Because attr_keyring uses a keyring, with access to multiple keys at once, key rotation is fairly straightforward: if you add a key to the keyring with a higher id than any other key, that key will automatically be used for encryption when records are either created or updated. Any keys that are no longer in use can be safely removed from the keyring.

To check if an existing key with id `123` is still in use, run:

```ruby
User.where(keyring_id: 123).empty?
```

For a large dataset, you may want to index the `keyring_id` column.

You may not want wait for records to be updated (e.g. key leaking). In that case, you can manually run something like the following:

```ruby
User.where(keyring_id: 1234).find_each do |user|
    user.keyring_rotate!
end
```

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

Everyone interacting in the AttrKeyring project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/fnando/attr_keyring/blob/master/CODE_OF_CONDUCT.md).
