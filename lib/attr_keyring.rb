module AttrKeyring
  require "attr_keyring/version"
  require "keyring"

  def self.active_record
    require "attr_keyring/active_record"
    ::AttrKeyring::ActiveRecord
  end
end
