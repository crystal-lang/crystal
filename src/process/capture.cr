class Process
  @[Experimental]
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

  @[Experimental]
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
    # The captured error stream might be truncated. If the total output is larger
    # than 64kB, only the first 32kB and the last 32kB are preserved.
    def error : String
      @error || ""
    end

    # Returns the captured `error` stream or an empty string.
    #
    # If `error` was not captured, returns `nil`.
    #
    # The captured error stream might be truncated. If the total output is larger
    # than 64kB, only the first 32kB and the last 32kB are preserved.
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
  @[Experimental]
  def self.capture_result(args : Enumerable(String), *, env : Env = nil, clear_env : Bool = false,
                          input : Stdio = Redirect::Close, output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Pipe, chdir : Path | String? = nil) : Result
    capture_result_impl(output, error) do |error|
      Process.new(args, env: env, clear_env: clear_env, input: input, output: output, error: error, chdir: chdir)
    end
  end

  # Executes a process and returns its result.
  #
  # Returns `nil` if the process fails to execute.
  #
  # If *error* or *output* are `Redirect::Pipe` (default), this method captures
  # the respective standard stream and returns it in the result.
  #
  # ```
  # Process.capture_result?(%w[echo foo]).try(&.output) # => "foo\n"
  # Process.capture_result?(%w[nonexist])               # => nil
  # ```
  @[Experimental]
  def self.capture_result?(args : Enumerable(String), *, env : Env = nil, clear_env : Bool = false,
                           input : Stdio = Redirect::Close, output : Stdio = Redirect::Pipe, error : Stdio = Redirect::Pipe, chdir : Path | String? = nil) : Result?
    capture_result_impl(output, error) do |error|
      Process.new(args, env: env, clear_env: clear_env, input: input, output: output, error: error, chdir: chdir) { return nil }
    end
  end

  private def self.capture_result_impl(output, error, & : -> Process)
    if error == Redirect::Pipe
      error = captured_error = IO::PrefixSuffixBuffer.new(32 << 10)
    end

    process = yield error

    if output == Redirect::Pipe
      captured_output = process.output.gets_to_end
    end

    process.close
    status = process.wait

    Result.new(status, captured_output, captured_error.try(&.to_s))
  end

  # Executes a process and returns its captured standard output.
  #
  # Raises `IO::Error` if the process fails to execute or `Process::ExitError`
  # if does not terminate with a zero exit status.
  #
  # If *error* is `Redirect::Pipe` (default), this method captures the standard
  # error and includes it in the raised `Process::ExitError`.
  #
  # ```
  # Process.capture(%w[echo foo]) # => "foo\n"
  # Process.capture(%w[nonexist]) # raises Process::ExitError
  # ```
  @[Experimental]
  def self.capture(args : Enumerable(String), *, env : Env = nil, clear_env : Bool = false,
                   input : Stdio = Redirect::Close, error : Stdio = Redirect::Pipe, chdir : Path | String? = nil) : String
    result = capture_result(args, env: env, clear_env: clear_env, input: input, error: error, chdir: chdir)
    if result.status.success?
      result.output
    else
      raise Process::ExitError.new(args, result)
    end
  end

  # Executes a process and returns its captured standard output or `nil` on failure.
  #
  # Raises `IO::Error` if the process fails to execute.
  # Returns nil if the process does not terminate with a zero exit status.
  #
  # The error stream is not captured by default, but it can be redirected into
  # an `IO`. `Redirect::Pipe` creates a pipe, but it cannot be accessed.
  #
  # ```
  # Process.capture(%w[echo foo]) # => "foo\n"
  # Process.capture(%w[nonexist]) # => nil
  # ```
  @[Experimental]
  def self.capture?(args : Enumerable(String), *, env : Env = nil, clear_env : Bool = false,
                    input : Stdio = Redirect::Close, error : Stdio = Redirect::Close, chdir : Path | String? = nil) : String?
    result = capture_result(args, env: env, clear_env: clear_env, input: input, error: error, chdir: chdir)

    if result.status.success?
      result.output
    end
  end
end
