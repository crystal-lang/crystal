require "c/stdlib"
require "c/unistd"

struct Crystal::System::Process
  getter pid : LibC::PidT

  def initialize(@pid : LibC::PidT)
  end

  def release
    raise NotImplementedError.new("Process#release")
  end

  def wait
    raise NotImplementedError.new("Process#wait")
  end

  def exists?
    raise NotImplementedError.new("Process#exists?")
  end

  def terminate(*, graceful)
    raise NotImplementedError.new("Process#terminate")
  end

  def self.exit(status)
    LibC.exit(status)
  end

  def self.pid
    # TODO: WebAssembly doesn't have the concept of processes.
    1
  end

  def self.pgid
    raise NotImplementedError.new("Process.pgid")
  end

  def self.pgid(pid)
    raise NotImplementedError.new("Process.pgid")
  end

  def self.ppid
    raise NotImplementedError.new("Process.ppid")
  end

  def self.signal(pid, signal)
    raise NotImplementedError.new("Process.signal")
  end

  def self.on_interrupt(&handler : ->) : Nil
    raise NotImplementedError.new("Process.on_interrupt")
  end

  def self.ignore_interrupts! : Nil
    raise NotImplementedError.new("Process.ignore_interrupts!")
  end

  def self.restore_interrupts! : Nil
    raise NotImplementedError.new("Process.restore_interrupts!")
  end

  def self.start_interrupt_loop : Nil
  end

  def self.exists?(pid)
    raise NotImplementedError.new("Process.exists?")
  end

  def self.times
    raise NotImplementedError.new("Process.times")
  end

  def self.fork(*, will_exec = false)
    raise NotImplementedError.new("Process.fork")
  end

  def self.fork(&)
    raise NotImplementedError.new("Process.fork")
  end

  def self.spawn(command_args, env, clear_env, input, output, error, chdir)
    raise NotImplementedError.new("Process.spawn")
  end

  def self.prepare_args(command : String, args : Enumerable(String)?, shell : Bool) : Array(String)
    raise NotImplementedError.new("Process.prepare_args")
  end

  def self.replace(command_args, env, clear_env, input, output, error, chdir)
    raise NotImplementedError.new("Process.replace")
  end

  def self.chroot(path)
    raise NotImplementedError.new("Process.chroot")
  end
end
