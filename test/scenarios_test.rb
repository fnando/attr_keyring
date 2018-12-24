require "test_helper"

class ScenariosTest < Minitest::Test
  def self.scenario_encrypt(encryption, scenario)
    test "encrypts value (#{encryption})" do
      keyring = Keyring.new({scenario.dig("key", "id") => scenario.dig("key", "value")}, encryption)
      encrypted, keyring_id, digest = keyring.encrypt(scenario["input"])

      assert_equal scenario.dig("encrypted", "keyring_id"), keyring_id
      assert_equal scenario.dig("encrypted", "digest"), digest
      assert_equal scenario["input"], keyring.decrypt(encrypted, keyring_id)
    end

    test "decrypts value (#{encryption})" do
      keyring = Keyring.new({scenario.dig("key", "id") => scenario.dig("key", "value")}, encryption)
      decrypted = keyring.decrypt(scenario.dig("encrypted", "value"), scenario.dig("encrypted", "keyring_id"))
      assert_equal scenario["input"], decrypted
    end
  end

  def self.scenario_rotate(encryption, scenario)
    test "rotates key (#{encryption})" do
      keyring = Keyring.new({scenario.dig("key", "id") => scenario.dig("key", "value")}, encryption)
      encrypted, keyring_id, digest = keyring.encrypt(scenario["input"])

      assert_equal scenario.dig("encrypted", "keyring_id"), keyring_id
      assert_equal scenario.dig("encrypted", "digest"), digest
      assert_equal scenario["input"], keyring.decrypt(encrypted, keyring_id)

      keyring[scenario.dig("rotate", "key", "id")] = scenario.dig("rotate", "key", "value")
      encrypted, keyring_id, digest = keyring.encrypt(scenario["input"])

      assert_equal scenario.dig("rotate", "encrypted", "keyring_id"), keyring_id
      assert_equal scenario.dig("rotate", "encrypted", "digest"), digest
      assert_equal scenario["input"], keyring.decrypt(encrypted, keyring_id)
    end
  end

  def self.scenario_update(encryption, scenario)
    test "update attribute (#{encryption})" do
      keyring = Keyring.new({scenario.dig("key", "id") => scenario.dig("key", "value")}, encryption)
      encrypted, keyring_id, digest = keyring.encrypt(scenario["input"])

      assert_equal scenario.dig("encrypted", "keyring_id"), keyring_id
      assert_equal scenario.dig("encrypted", "digest"), digest
      assert_equal scenario["input"], keyring.decrypt(encrypted, keyring_id)

      encrypted, keyring_id, digest = keyring.encrypt(scenario.dig("update", "input"))

      assert_equal scenario.dig("update", "encrypted", "keyring_id"), keyring_id
      assert_equal scenario.dig("update", "encrypted", "digest"), digest
      assert_equal scenario.dig("update", "input"), keyring.decrypt(encrypted, keyring_id)
    end
  end

  data = JSON.parse(File.read(File.expand_path("data.json", __dir__)))
  data.each do |encryption, scenarios|
    scenarios.each do |scenario|
      action = scenario["action"]
      encryptor = case encryption
                  when "aes-128-cbc"
                    Keyring::Encryptor::AES::AES128CBC
                  when "aes-192-cbc"
                    Keyring::Encryptor::AES::AES192CBC
                  when "aes-256-cbc"
                    Keyring::Encryptor::AES::AES256CBC
                  else
                    raise "Invalid encryption; #{encryption}"
                  end

      public_send("scenario_#{action}", encryptor, scenario)
    end
  end
end
