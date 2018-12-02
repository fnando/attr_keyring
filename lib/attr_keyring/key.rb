module AttrKeyring
  class Key
    attr_reader :id, :value

    def initialize(id, value)
      @id = Integer(id)
      @value = decode(value)
    end

    def to_s
      "#<AttrKeyring::Key id=#{id.inspect}>"
    end
    alias_method :inspect, :to_s

    private def decode(secret)
      return secret if secret.bytesize == 16

      value = begin
                Base64.strict_decode64(secret)
              rescue ArgumentError
                Base64.decode64(secret)
              end

      return value if value.bytesize == 16

      raise InvalidSecret, "Secret must be 16 bytes, instead got #{value.bytesize}"
    end
  end
end
