struct Exception::CallStack
  def self.decode_address(ip)
    ip
  end

  def self.decode_line_number(pc)
    {"??", 0, 0}
  end

  def self.decode_function_name(pc)
    nil
  end
end
