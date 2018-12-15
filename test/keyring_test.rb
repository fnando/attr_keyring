require "test_helper"

class KeyringTest < Minitest::Test
  test "prevents key leaking" do
    key = Keyring::Key.new(1, SecureRandom.bytes(16), 16)

    assert_equal "#<AttrKeyring::Key id=1>", key.to_s
    assert_equal "#<AttrKeyring::Key id=1>", key.inspect
  end

  test "returns digest when encrypting" do
    keys = {"0" => "2EPEXzEVZqVbIbfZXfe3Ew=="}
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES128CBC)

    *, digest = keyring.encrypt("42")

    assert_equal "92cfceb39d57d914ed8b14d0e37643de0797ae56", digest

    keyring[1] = "5nAp51BMNKNh2zECMFEQ0Q=="
    *, digest = keyring.encrypt("37")

    assert_equal "cb7a1d775e800fd1ee4049f7dca9e041eb9ba083", digest
  end

  test "returns keyring id when encrypting" do
    keys = {"0" => "2EPEXzEVZqVbIbfZXfe3Ew=="}
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES128CBC)

    _, keyring_id, _ = keyring.encrypt("42")

    assert_equal 0, keyring_id

    keyring[1] = "5nAp51BMNKNh2zECMFEQ0Q=="
    _, keyring_id, _ = keyring.encrypt("42")

    assert_equal 1, keyring_id
  end

  test "rotates key" do
    # First encrypt and decrypt value using initial key.
    keys = {"0" => "2EPEXzEVZqVbIbfZXfe3Ew=="}
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES128CBC)
    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal 0, keyring_id
    assert_equal "42", decrypted

    # Then add a new key and encrypt and decrypt value using new key.
    keys = keys.merge("1" => "5nAp51BMNKNh2zECMFEQ0Q==")
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES128CBC)
    encrypted, keyring_id, _ = keyring.encrypt(decrypted)
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal 1, keyring_id
    assert_equal "42", decrypted

    # Finally, remove key=0 and encrypt and decrypt value.
    keys.delete("0")
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES128CBC)
    encrypted, keyring_id, _ = keyring.encrypt(decrypted)
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal 1, keyring_id
    assert_equal "42", decrypted
  end

  test "encrypts using AES-128-CBC" do
    keys = {"0" => "2EPEXzEVZqVbIbfZXfe3Ew=="}
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES128CBC)

    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal "42", decrypted
  end

  test "encrypts using AES-192-CBC" do
    keys = {"0" => "zfttbrsNvHU89lNFuNRs0ajZugaxK5Wj"}
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES192CBC)

    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal "42", decrypted
  end

  test "encrypts using AES-256-CBC" do
    keys = {"0" => "oOWEmzx5RGEgKlZ2ugbQ0kotliI2K3jAZ2gPfTvkRNU="}
    keyring = Keyring.new(keys, Keyring::Encryptor::AES::AES256CBC)

    encrypted, keyring_id, _ = keyring.encrypt("42")
    decrypted = keyring.decrypt(encrypted, keyring_id)

    assert_equal "42", decrypted
  end
end
