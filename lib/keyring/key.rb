module Keyring
  class Key
    attr_reader :id, :value

    def initialize(id, value, key_size)
      @id = Integer(id)
      @key_size = key_size
      @value = decode(value)
    end

    def to_s
      "#<AttrKeyring::Key id=#{id.inspect}>"
    end
    alias_method :inspect, :to_s

    private def decode(secret)
      return secret if secret.bytesize == @key_size

      value = begin
                Base64.strict_decode64(secret)
              rescue ArgumentError
                Base64.decode64(secret)
              end

      return value if value.bytesize == @key_size

      raise InvalidSecret, "Secret must be #{@key_size} bytes, instead got #{value.bytesize}"
    end
  end
end
