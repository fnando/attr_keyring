# frozen_string_literal: true

require "test_helper"

class KeyTest < Minitest::Test
  test "prevents key leaking" do
    key = Keyring::Key.new(1, "uDiMcWVNTuz//naQ88sOcN+E40CyBRGzGTT7OkoBS6M=", 16)

    assert_equal "#<Keyring::Key id=1>", key.to_s
    assert_equal "#<Keyring::Key id=1>", key.inspect
  end

  test "accepts keys with valid size (bytes)" do
    key = Keyring::Key.new(1, SecureRandom.bytes(32), 16)

    assert_instance_of Keyring::Key, key
  end

  test "accepts keys with valid size (base64-encoded)" do
    key = Keyring::Key.new(1, Base64.encode64(SecureRandom.bytes(32)), 16)

    assert_instance_of Keyring::Key, key
  end

  test "accepts keys with valid size (base64-strict-encoded)" do
    key =
      Keyring::Key.new(1, Base64.strict_encode64(SecureRandom.bytes(32)), 16)

    assert_instance_of Keyring::Key, key
  end

  test "raises when key has invalid size" do
    assert_raises(Keyring::InvalidSecret, "Secret must be 32 bytes, instead got 16") do
      Keyring::Key.new(1, SecureRandom.bytes(16), 16)
    end
  end

  test "parses key (AES-128-CBC)" do
    signing_key = "A" * 16
    encryption_key = "B" * 16
    key = Keyring::Key.new(1, signing_key + encryption_key, 16)

    assert_equal encryption_key, key.encryption_key
    assert_equal signing_key, key.signing_key
  end

  test "parses key (AES-192-CBC)" do
    signing_key = "A" * 24
    encryption_key = "B" * 24
    key = Keyring::Key.new(1, signing_key + encryption_key, 24)

    assert_equal encryption_key, key.encryption_key
    assert_equal signing_key, key.signing_key
  end

  test "parses key (AES-256-CBC)" do
    signing_key = "A" * 32
    encryption_key = "B" * 32
    key = Keyring::Key.new(1, signing_key + encryption_key, 32)

    assert_equal encryption_key, key.encryption_key
    assert_equal signing_key, key.signing_key
  end
end
