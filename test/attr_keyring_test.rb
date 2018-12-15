require "test_helper"

class AttrKeyringTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  setup do
    ActiveRecord::Base.connection.execute "truncate users"
  end

  test "raises exception when default keyring is used" do
    model_class = create_model do
      attr_encrypt :secret
    end

    assert_raises(Keyring::EmptyKeyring) do
      model_class.create(secret: "42")
    end
  end

  test "encrypts value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
  end

  test "saves keyring id" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal 0, user.keyring_id
  end

  test "handles nil values during encryption" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret, :other_secret
    end

    user = model_class.create(secret: "42", other_secret: nil)
    user.reload

    assert_equal "42", user.secret
    assert_nil user.other_secret
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

    user = user_class.create(secret: "42")
    customer = customer_class.create(super_secret: "37")

    user.reload
    customer.reload

    assert_equal "42", user.secret
    assert_equal "37", customer.super_secret
  end

  test "saves digest value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", user.secret_digest
  end

  test "updates encrypted value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
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

    user = model_class.create(secret: "42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", user.secret_digest

    user.secret = "37"
    user.save!
    user.reload

    assert_equal "cb7a1d775e800fd1ee4049f7dca9e041eb9ba083", user.secret_digest
  end

  test "assigns digest even without saving" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.new(secret: "42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", user.secret_digest
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

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret

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

    user = model_class.create(secret: "42")

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

    user = model_class.create(secret: "42")

    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.save!
    user.reload

    assert_equal "42", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts several columns at once" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret, :other_secret
    end

    user = model_class.create(secret: "42", other_secret: "other secret")
    user.reload

    assert_equal "42", user.secret
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

    user = model_class.create(secret: "42", other_secret: "other secret")
    user.reload

    assert_equal "42", user.secret
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

  test "encrypts column with most recent key" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg==",
                   "1" => "5nAp51BMNKNh2zECMFEQ0Q=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 1, user.keyring_id
  end

  test "raises exception when key is missing" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")

    model_class.keyring.clear
    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.reload

    assert_raises(Keyring::UnknownKey) { user.secret }
  end

  test "caches decrypted value" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    model_class.keyring.expects(:decrypt).once.returns("DECRYPTED")

    user = model_class.create(secret: "42")
    2.times { user.secret }
  end

  test "clears cache when assigning values" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    model_class.keyring.expects(:decrypt).twice.returns("DECRYPTED")

    user = model_class.create(secret: "42")
    user.secret
    user.secret = "37"
    user.secret
  end

  test "rotates key" do
    model_class = create_model do
      attr_keyring "0" => "XSzMZOONFkli/hiArK9dKg=="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id

    model_class.keyring["1"] = "5nAp51BMNKNh2zECMFEQ0Q=="

    user.keyring_rotate!
    user.reload

    assert_equal "42", user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts value using raw bytes key" do
    model_class = create_model do
      attr_keyring "0" => SecureRandom.bytes(16)
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts value base64 encoded key" do
    model_class = create_model do
      attr_keyring "0" => Base64.encode64(SecureRandom.bytes(16))
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts value base64 strict encoded key" do
    model_class = create_model do
      attr_keyring "0" => Base64.strict_encode64(SecureRandom.bytes(16))
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  test "raises exception with invalid key size" do
    model_class = create_model do
      attr_keyring Hash.new
    end

    assert_raises(Keyring::InvalidSecret, "Secret must be 16 bytes, instead got 32") do
      model_class.keyring["0"] = Base64.strict_encode64(SecureRandom.bytes(32))
    end
  end

  test "encrypts using AES-128-CBC" do
    model_class = create_model do
      keyring_store = {"0" => "2EPEXzEVZqVbIbfZXfe3Ew=="}
      attr_keyring keyring_store, encryptor: Keyring::Encryptor::AES::AES128CBC
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts using AES-192-CBC" do
    model_class = create_model do
      keyring_store = {"0" => "zfttbrsNvHU89lNFuNRs0ajZugaxK5Wj"}
      attr_keyring keyring_store, encryptor: Keyring::Encryptor::AES::AES192CBC
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  test "decrypts node's aes-128-cbc encryption" do
    encrypted = "kdyvxF3yiToqlI/U91wxXkc5DB6vJvdgWfHxFCpy1Ko="

    model_class = create_model do
      keyring_store = {"0" => "XSzMZOONFkli/hiArK9dKg=="}
      attr_keyring keyring_store, encryptor: Keyring::Encryptor::AES::AES128CBC
      attr_encrypt :secret
    end

    user = model_class.create(encrypted_secret: encrypted)

    assert_equal "42", user.secret
  end

  def create_model(&block)
    Class.new(ActiveRecord::Base) do
      self.table_name = :users
      include AttrKeyring
      instance_eval(&block)
    end
  end
end
