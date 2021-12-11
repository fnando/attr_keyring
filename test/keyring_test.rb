# frozen_string_literal: true

require "test_helper"

class KeyringTest < Minitest::Test
  test "returns digest when encrypting" do
    keys = {"0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
    keyring = Keyring.new(keys, digest_salt: "")

    *, digest = keyring.encrypt("42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", digest

    keyring[1] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="
    *, digest = keyring.encrypt("37")

    assert_equal "cb7a1d775e800fd1ee4049f7dca9e041eb9ba083", digest
  end

  test "returns digest with custom salt" do
    digest_salt = "a"
    keys = {"0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
    keyring = Keyring.new(keys, digest_salt: digest_salt)

    *, digest = keyring.encrypt("42")

    assert_equal "118c884d37dde5fb6816daba052d94e82f1dc41f", digest

    keyring[1] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="
    *, digest = keyring.encrypt("37")

    assert_equal "339306c56026a22fdd522116973cde9a8205370e", digest
  end

  test "fails with missing digest salt" do
    error = assert_raises(Keyring::MissingDigestSalt) do
      Keyring.new({})
    end

    assert_includes error.message, "Please provide :digest_salt"

    Keyring.new({}, digest_salt: "")
  end

  test "returns keyring id when encrypting" do
    keys = {"0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
    keyring = Keyring.new(keys, digest_salt: "")

    _, keyring_id, _ = keyring.encrypt("42")

    assert_equal 0, keyring_id

    keyring[1] = "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc="
    _, keyring_id, _ = keyring.encrypt("42")

    assert_equal 1, keyring_id
  end

  test "rotates key" do
    # First encrypt and decrypt value using initial key.
    keys = {"0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
    keyring = Keyring.new(keys, digest_salt: "")
    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal 0, keyring_id
    assert_equal "42", decrypted

    # Then add a new key and encrypt and decrypt value using new key.
    keys = keys.merge("1" => "VN8UXRVMNbIh9FWEFVde0q7GUA1SGOie1+FgAKlNYHc=")
    keyring = Keyring.new(keys, digest_salt: "")
    encrypted, keyring_id, _ = keyring.encrypt(decrypted)
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal 1, keyring_id
    assert_equal "42", decrypted

    # Finally, remove key=0 and encrypt and decrypt value.
    keys.delete("0")
    keyring = Keyring.new(keys, digest_salt: "")
    encrypted, keyring_id, _ = keyring.encrypt(decrypted)
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal 1, keyring_id
    assert_equal "42", decrypted
  end

  test "encrypts using AES-128-CBC" do
    keys = {"0" => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
    keyring = Keyring.new(keys, encryptor: Keyring::Encryptor::AES::AES128CBC, digest_salt: "")

    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal "42", decrypted
  end

  test "encrypts using AES-192-CBC" do
    keys = {"0" => "wtnnoK+5an+FPtxnkdUDrNw6fAq8yMkvCvzWpriLL9TQTR2WC/k+XPahYFPvCemG"}
    keyring = Keyring.new(keys, encryptor: Keyring::Encryptor::AES::AES192CBC, digest_salt: "")

    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal "42", decrypted
  end

  test "encrypts using AES-256-CBC" do
    keys = {"0" => "XZXC+c7VUVGpyAceSUCOBbrp2fjJeeHwoaMQefgSCfp0/HABY5yJ7zRiLZbDlDZ7HytCRsvP4CxXt5hUqtx9Uw=="}
    keyring = Keyring.new(keys, encryptor: Keyring::Encryptor::AES::AES256CBC, digest_salt: "")

    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal "42", decrypted
  end

  test "decrypts attr_vault value" do
    key = "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="
    encrypted = Base64.strict_encode64(AttrVault::Cryptor.encrypt("42", key))
    keyring = Keyring.new({"0" => key}, digest_salt: "")

    decrypted = keyring.decrypt(encrypted, 0)

    assert_equal "42", decrypted
  end

  test "works with keys as symbols (rails 7.0 fix)" do
    sym_key = "0".to_sym
    keys = {sym_key => "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M="}
    keyring = Keyring.new(keys, digest_salt: "")

    *, digest = keyring.encrypt("42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", digest
  end
end
