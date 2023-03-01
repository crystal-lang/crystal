# :nodoc:
struct Crystal::System::Process
  # Implementation-dependent "conceptual" data types (they only need to match across arg types and return types):
  # * ProcessInformation: The system-dependent value with enough information to keep track of a running process.
  #   Could be the PID or similar.
  # * Args: The system-native way to specify an executable with its command line arguments.
  #   Could be an array of strings or a single string.

  # Creates a structure representing a running process based on its ID.
  # def self.new(pi : ProcessInformation)

  # Releases any resources acquired by this structure.
  # def release

  # Returns the PID of the running process.
  # def pid : Int

  # Waits until the process finishes and returns its status code
  # def wait : Int

  # Whether the process is still registered in the system.
  # def exists? : Bool

  # Asks this process to terminate.
  # def terminate(*, graceful)

  # Terminates the current process immediately.
  # def self.exit(status : Int)

  # Returns the process identifier of the current process.
  # def self.pid : Int

  # Returns the process group identifier of the current process.
  # def self.pgid : Int

  # Returns the process group identifier of the process identified by *pid*.
  # def self.pgid(pid) : Int

  # Returns the process identifier of the parent process of the current process.
  # def self.ppid : Int

  # Sends a *signal* to the processes identified by the given *pids*.
  # def self.signal(pid : Int, signal : Int)

  # Installs *handler* as the new handler for interrupt requests. Removes any
  # previously set interrupt handler.
  # def self.on_interrupt(&handler : ->)

  # Ignores all interrupt requests. Removes any custom interrupt handler set
  # def self.ignore_interrupts!

  # Restores default handling of interrupt requests.
  # def self.restore_interrupts!

  # Spawns a fiber responsible for executing interrupt handlers on the main
  # thread.
  # def self.start_interrupt_loop

  # Whether the process identified by *pid* is still registered in the system.
  # def self.exists?(pid : Int) : Bool

  # Measures CPU times.
  # def self.times : ::Process::Tms

  # Duplicates the current process.
  # def self.fork : ProcessInformation
  # def self.fork(&)

  # Launches a child process with the command + args.
  # def self.spawn(command_args : Args, env : Env?, clear_env : Bool, input : Stdio, output : Stdio, error : Stdio, chdir : Path | String?) : ProcessInformation

  # Replaces the current process with a new one.
  # def self.replace(command_args : Args, env : Env?, clear_env : Bool, input : Stdio, output : Stdio, error : Stdio, chdir : Path | String?) : NoReturn

  # Converts a command and array of arguments to the system-specific representation.
  # def self.prepare_args(command : String, args : Enumerable(String)?, shell : Bool) : Args

  # Changes the root directory for the current process.
  # def self.chroot(path : String)
end

module Crystal::System
  ORIGINAL_STDIN  = IO::FileDescriptor.new(0, blocking: true)
  ORIGINAL_STDOUT = IO::FileDescriptor.new(1, blocking: true)
  ORIGINAL_STDERR = IO::FileDescriptor.new(2, blocking: true)
end

{% if flag?(:wasi) %}
  require "./wasi/process"
{% elsif flag?(:unix) %}
  require "./unix/process"
{% elsif flag?(:win32) %}
  require "./win32/process"
{% else %}
  {% raise "No Crystal::System::Process implementation available" %}
{% end %}
