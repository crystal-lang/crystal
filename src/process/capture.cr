class Process
  class ExitError < Exception
    getter args : Enumerable(String)
    getter result : Result

    def initialize(@args : Enumerable(String), @result : Result)
      description = if code = result.status.exit_code?
                      "Process exited with status #{code}"
                    else
                      result.status.description
                    end
      super("Command #{args.inspect} failed: #{description}")
    end
  end

  struct Process::Result
    def initialize(@status : Status, @output : String?, @error : String?)
    end

    # Returns the captured `output` stream or an empty string.
    #
    # If `output` was not captured, returns the empty string.
    def output : String
      @output || ""
    end

    # Returns the captured `output` stream.
    #
    # If `output` was not captured, returns `nil`.
    def output? : String?
      @output
    end

    # Returns the captured `error` stream or an empty string.
    #
    # If `error` was not captured, returns the empty string.
    #
    # The captured error stream might be truncated.
    def error : String
      @error || ""
    end

    # Returns the captured `error` stream or an empty string.
    #
    # If `error` was not captured, returns `nil`.
    #
    # The captured error stream might be truncated.
    def error? : String?
      @error
    end

    # Returns the status of the process.
    def status : Process::Status
      @status
    end
  end

  # Executes a process and returns its result.
  #
  # Raises `IO::Error` if the process fails to execute.
  #
  # If *error* or *output* are `Redirect::Pipe` (default), this method captures
  # the respective standard stream and returns it in the result.
  #
  # ```
  # Process.capture_result(%w[echo foo]).output # => "foo\n"
  # Process.capture_result(%w[nonexist])        # raises Process::ExitError
  # ```
  def self.capture_result(args : Enumerable(String), *, env : Env = nil, clear_env : Bool = false,
                          input : Stdio = Redirect::Close, output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Pipe, chdir : Path | String? = nil) : Result
    if error == Redirect::Pipe
      error = captured_error = IO::Memory.new
    end

    process = Process.new(args, env: env, clear_env: clear_env, input: input, output: output, error: error, chdir: chdir)

    if output == Redirect::Pipe
      captured_output = process.output.gets_to_end
    end

    process.close
    status = process.wait

    Result.new(status, captured_output, captured_error.try(&.to_s))
  end
end
