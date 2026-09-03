struct ProcessStatusExpectation
  def initialize(@expected_status : Process::Status)
  end

  def match(actual_status : Process::Status)
    actual_status == @expected_status
  end

  def match(result : Process::Result)
    match(result.status)
  end

  def failure_message(actual_value : Process::Status)
    "Expected process exit status to be #{@expected_status}, but it was #{actual_value}"
  end

  def failure_message(result : Process::Result)
    String.build do |io|
      io << failure_message(result.status)
      if output = result.output?
        io << "\nOutput:\n"
        io.puts output
      end
      if error = result.error?
        io << "\nError:\n"
        io.puts error
      end
    end
  end
end

module Spec::Expectations
  def be_success
    ProcessStatusExpectation.new(Process::Status[0])
  end

  def be_failure(status : Process::Status = Process::Status[1])
    ProcessStatusExpectation.new(status)
  end

  def be_failure(status : Int32)
    be_failure Process::Status[status]
  end
end
