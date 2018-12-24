require "test_helper"

class SequelTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  setup do
    DB.run "truncate users"
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
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
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
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal 0, user.keyring_id
  end

  test "handles nil values during encryption" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret, :other_secret
    end

    user = model_class.create(secret: "42", other_secret: nil)
    user.reload

    assert_equal "42", user.secret
    assert_nil user.other_secret
  end

  test "saves digest value" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", user.secret_digest
  end

  test "updates encrypted value" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.secret = "new secret"
    user.save

    user.reload

    assert_equal "new secret", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 0, user.keyring_id
  end

  test "updates digest" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", user.secret_digest

    user.secret = "37"
    user.save
    user.reload

    assert_equal "cb7a1d775e800fd1ee4049f7dca9e041eb9ba083", user.secret_digest
  end

  test "assigns digest even without saving" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.new(secret: "42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", user.secret_digest
  end

  test "assigns nil values" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.new(secret: nil)

    assert_nil user.secret
    assert_nil user.encrypted_secret
    assert_nil user.secret_digest
  end

  test "assigns non-string values" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: 1234)
    user.reload

    assert_equal "1234", user.secret
  end

  test "assigns nil after saving encrypted value" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
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
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")

    model_class.keyring["1"] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="

    user.update(secret: "new secret")
    user.reload

    assert_equal "new secret", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts with newer key when saving" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")

    model_class.keyring["1"] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="

    user.save
    user.reload

    assert_equal "42", user.secret
    refute_nil user.encrypted_secret
    refute_equal user.encrypted_secret, user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts several columns at once" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
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
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret, :other_secret
    end

    user = model_class.create(secret: "42", other_secret: "other secret")
    user.reload

    assert_equal "42", user.secret
    assert_equal "other secret", user.other_secret
    assert_equal 0, user.keyring_id

    model_class.keyring["1"] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="

    user.secret = "new secret"
    user.save
    user.reload

    assert_equal "new secret", user.secret
    assert_equal "other secret", user.other_secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts column with most recent key" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M=",
                   "1" => "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 1, user.keyring_id
  end

  test "raises exception when key is missing" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    model_class.create(secret: "42")

    model_class.keyring.clear
    model_class.keyring["1"] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="

    assert_raises(Keyring::UnknownKey) { model_class.first.secret }
  end

  test "caches decrypted value" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    model_class.keyring.expects(:decrypt).once.returns("DECRYPTED")

    user = model_class.create(secret: "42")
    2.times { user.secret }
  end

  test "clears cache when assigning values" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
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
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id

    model_class.keyring["1"] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="

    user.keyring_rotate!
    user.reload

    assert_equal "42", user.secret
    assert_equal 1, user.keyring_id
  end

  test "encrypts all attributes when setting only one attribute" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret, :other_secret
    end

    model_class.create(secret: "42", other_secret: "37")
    user = model_class.first

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id

    model_class.keyring["1"] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="

    user.secret = "24"
    user.save

    user.reload

    assert_equal "24", user.secret
    assert_equal "37", user.other_secret
    assert_equal 1, user.keyring_id
  end

  test "returns unitialized attributes" do
    model_class = create_model do
      attr_keyring "0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
      attr_encrypt :secret
    end

    user = model_class.new

    assert_nil user.secret
  end

  test "encrypts using AES-128-CBC" do
    model_class = create_model do
      keyring_store = {"0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
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
      keyring_store = {"0" => "wtnnoK+5an+FPtxnkdUDrNw6fAq8yMkvCvzWpriLL9TQTR2WC/k+XPahYFPvCemG"}
      attr_keyring keyring_store, encryptor: Keyring::Encryptor::AES::AES192CBC
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  test "encrypts using AES-256-CBC" do
    model_class = create_model do
      keyring_store = {"0" => "XZXC+c7VUVGpyAceSUCOBbrp2fjJeeHwoaMQefgSCfp0/HABY5yJ7zRiLZbDlDZ7HytCRsvP4CxXt5hUqtx9Uw=="}
      attr_keyring keyring_store, encryptor: Keyring::Encryptor::AES::AES256CBC
      attr_encrypt :secret
    end

    user = model_class.create(secret: "42")
    user.reload

    assert_equal "42", user.secret
    assert_equal 0, user.keyring_id
  end

  def create_model(&block)
    Class.new(Sequel::Model(:users)) do
      include AttrKeyring.sequel
      instance_eval(&block)
    end
  end
end
