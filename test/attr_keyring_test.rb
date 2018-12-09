require "test_helper"

class AttrKeyringTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  setup do
    ActiveRecord::Base.connection.execute "delete from users"
  end

  test "raises exception when default keyring is used" do
    model_class = create_model do
      attr_encrypt :secret
    end

    assert_raises(AttrKeyring::UnknownKey) do
      model_class.create(secret: "secret")
    end
  end

  test "encrypts value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    assert_equal "secret", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
  end

  test "encodes encrypted value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret, encode: true
    end

    user = model_class.create(secret: "secret")

    assert_equal "ASCII-8BIT", Base64.strict_decode64(user.encrypted_secret).encoding.name
  end

  test "deals with abstract classes and inheriting" do
    abstract_class = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      include AttrKeyring
    end

    user_class = Class.new(abstract_class) do
      self.table_name = :users

      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    customer_class = Class.new(abstract_class) do
      self.table_name = :customers

      attr_keyring "0" => "4OW/P/3eCTeD6UGfiMXtOQ=="
      attr_encrypt :super_secret
    end

    user = user_class.create(secret: "secret!")
    customer = customer_class.create(super_secret: "super secret!")

    user.reload
    customer.reload

    assert_equal "secret!", user.secret
    assert_equal "super secret!", customer.super_secret
  end

  test "saves digest value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    assert_equal "e5e9fa1ba31ecd1ae84f75caaa474f3a663f05f4", user.secret_digest
  end

  test "updates encrypted value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.secret = "new secret"
    user.save!

    user.reload

    assert_equal "new secret", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 0, user.keyring_id
  end

  test "updates digest" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    assert_equal "e5e9fa1ba31ecd1ae84f75caaa474f3a663f05f4", user.secret_digest

    user.secret = "new secret"
    user.save!
    user.reload

    assert_equal "950a376e47f2f00331f42dd65c7fc7eb39265ba2", user.secret_digest
  end

  test "assigns digest even without saving" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.new(secret: "secret")

    assert_equal "e5e9fa1ba31ecd1ae84f75caaa474f3a663f05f4", user.secret_digest
  end

  test "assigns nil values" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.new(secret: nil)

    assert_nil user.secret
    assert_nil user.encrypted_secret
    assert_nil user.secret_digest
  end

  test "assigns nil after saving encrypted value" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret

    user.secret = nil

    assert_nil user.secret
    assert_nil user.encrypted_secret
    assert_nil user.secret_digest
  end

  test "encrypts with newer key when assigning new value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.update(secret: "new secret")
    user.reload

    assert_equal "new secret", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts with newer key when saving" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.save!
    user.reload

    assert_equal "secret", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts several columns at once" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret, :other_secret
    end

    user = model_class.create(secret: "secret", other_secret: "other secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal "other secret", user.other_secret
    refute_nil user.encrypted_secret
    refute_nil user.encrypted_other_secret
    refute_equal user.encrypted_secret, user.secret
    refute_equal user.encrypted_other_secret, user.other_secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts columns with different keys set at different times" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret, :other_secret
    end

    user = model_class.create(secret: "secret", other_secret: "other secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal "other secret", user.other_secret
    assert_equal 0, user.keyring_id

    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.secret = "new secret"
    user.save!
    user.reload

    assert_equal "new secret", user.secret
    assert_equal "other secret", user.other_secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts column after rotating key" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg==",
                   "1" => "5nAp51BMNKNh2zECMFEQ0Q=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal 1, user.keyring_id
  end

  test "raises exception when key is missing" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    model_class.keyring.clear
    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    assert_raises(AttrKeyring::UnknownKey) { user.secret }
  end

  test "rotates key" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal 0, user.keyring_id

    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.keyring_rotate!
    user.reload

    assert_equal "secret", user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts value using raw bytes key" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts value base64 encoded key" do
    model_class = create_model do
      attr_keyring "0" => Base64.encode64(SecureRandom.bytes(16))
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts value base64 strict encoded key" do
    model_class = create_model do
      attr_keyring "0" => Base64.strict_encode64(SecureRandom.bytes(16))
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal 0, user.keyring_id
  end

  test "raises exception with invalid key size" do
    model_class = create_model do
      attr_keyring Hash.new
    end

    assert_raises(AttrKeyring::InvalidSecret, "Secret must be 16 bytes, instead got 32") do
      model_class.keyring["0"] = Base64.strict_encode64(SecureRandom.bytes(32))
    end
  end

  test "encrypts using AES-256-CBC" do
    model_class = create_model do
      keyring_store = {"0" => SecureRandom.bytes(32)}
      attr_keyring keyring_store, encryptor: AttrKeyring::Encryptor::AES256CBC
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")
    user.reload

    assert_equal "secret", user.secret
    assert_equal 0, user.keyring_id
  end

  test "prevents key leaking" do
    key = AttrKeyring::Key.new(1, SecureRandom.bytes(16), 16)

    assert_equal "#<AttrKeyring::Key id=1>", key.to_s
    assert_equal "#<AttrKeyring::Key id=1>", key.inspect
  end

  def create_model(&block)
    Class.new(ActiveRecord::Base) do
      self.table_name = :users
      include AttrKeyring
      instance_eval(&block)
    end
  end
end
