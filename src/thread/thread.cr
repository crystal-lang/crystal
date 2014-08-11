require "lib_pthread"
require "./*"

class Thread(T, R)
  def self.new(&func : -> R)
    Thread(Nil, R).new(nil) { func.call }
  end

  def initialize(arg : T, &func : T -> R)
    @func = func
    @arg = arg
    PThread.create(out @th, nil, ->(data) {
        (data as Thread(T, R)).start
      }, self as Void*)
  end

  def start
    ret = Pointer(R).malloc_one(@func.call(@arg))
    PThread.exit(ret as Void*)
  end

  def join
    PThread.join(@th, out ret)
    (ret as R*).value
  end
end
