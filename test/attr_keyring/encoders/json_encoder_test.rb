# frozen_string_literal: true

require "test_helper"

class JSONEncoderTest < Minitest::Test
  test "symbolizes keys" do
    expected = {message: "hello"}
    payload_string = AttrKeyring::Encoders::JSONEncoder.dump(expected)

    assert_equal expected,
                 AttrKeyring::Encoders::JSONEncoder.parse(payload_string)
  end
end
