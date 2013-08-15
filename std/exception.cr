class Exception
  getter :message
  getter :inner_exception

  def initialize(message = nil, inner_exception = nil)
    @message = message
    @inner_exception = inner_exception
  end

  def to_s
    @message
  end
end
