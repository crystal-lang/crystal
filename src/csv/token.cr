struct CSV::Token
  property kind
  property value

  def initialize
    @kind = :eof
    @value = ""
  end
end

