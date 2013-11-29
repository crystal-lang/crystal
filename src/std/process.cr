lib C
  fun fork : Int32
  fun getpid : Int32
  fun getppid : Int32
  fun exit(status : Int32) : NoReturn
end

module Process
  def self.exit(status = 0)
    C.exit(status)
  end

  def self.pid
    C.getpid()
  end

  def self.ppid
    C.getppid()
  end

  def self.fork(&block)
    pid = self.fork()

    unless pid
      yield
      exit
    end

    pid
  end

  def self.fork()
    pid = C.fork
    pid = nil if pid == 0
    pid
  end
end
