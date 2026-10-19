abstract class Crystal::EventLoop
  module Process
    # Waits for a child process to terminate, reaps it and returns its exit
    # status.
    abstract def wait(process : System::Process) : ::Process::Status
  end
end
