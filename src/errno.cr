lib C
  $errno : Int32
  fun strerror(errnum : Int32) : Char*
end

class Errno < Exception
  def initialize(message)
    super "#{message}: #{String.new(C.strerror(C.errno))}"
  end
end
