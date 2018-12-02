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

  test "saves digest value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "secret")

    assert_equal "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b", user.secret_digest
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

    assert_equal "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b", user.secret_digest

    user.secret = "new secret"
    user.save!
    user.reload

    assert_equal "859601deb772672b933ef30d66609610c928bcf116951a52f4b8698f34c1fc80", user.secret_digest
  end

  test "assigns digest even without saving" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.new(secret: "secret")

    assert_equal "2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b", user.secret_digest
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

  test "prevents key leaking" do
    key = AttrKeyring::Key.new(1, SecureRandom.bytes(16))

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
