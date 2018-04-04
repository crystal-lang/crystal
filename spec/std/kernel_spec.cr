require "spec"
require "tempfile"

private def build_and_run(code)
  code_file = Tempfile.new("exit_spec_code")
  code_file.close

  # write code to the temp file
  File.write(code_file.path, code)

  binary_file = Tempfile.new("exit_spec_output")
  binary_file.close

  `bin/crystal build #{code_file.path.inspect} -o #{binary_file.path.inspect}`
  File.exists?(binary_file.path).should be_true

  out_io, err_io = IO::Memory.new, IO::Memory.new
  status = Process.run binary_file.path, output: out_io, error: err_io

  {status, out_io.to_s, err_io.to_s}
ensure
  File.delete(code_file.path) if code_file
  File.delete(binary_file.path) if binary_file
end

describe "exit" do
  it "exits normally with status 0" do
    status, _ = build_and_run "exit"
    status.success?.should be_true
  end

  it "exits with given error code" do
    status, _ = build_and_run "exit 42"
    status.success?.should be_false
    status.exit_code.should eq(42)
  end
end

describe "at_exit" do
  it "runs handlers on normal program ending" do
    status, output = build_and_run <<-CODE
      at_exit do
        puts "handler code"
      end
    CODE

    status.success?.should be_true
    output.should eq("handler code\n")
  end

  it "runs handlers on explicit program ending" do
    status, output = build_and_run <<-'CODE'
      at_exit do |exit_code|
        puts "handler code, exit code: #{exit_code}"
      end

      exit 42
    CODE

    status.exit_code.should eq(42)
    output.should eq("handler code, exit code: 42\n")
  end

  it "runs handlers in reverse order" do
    status, output = build_and_run <<-CODE
      at_exit do
        puts "first handler code"
      end

      at_exit do
        puts "second handler code"
      end
    CODE

    status.success?.should be_true
    output.should eq <<-OUTPUT
                       second handler code
                       first handler code

                       OUTPUT
  end

  it "runs all handlers maximum once" do
    status, output = build_and_run <<-CODE
      at_exit do
        puts "first handler code"
      end

      at_exit do
        puts "second handler code, explicit exit!"
        exit

        puts "not executed"
      end

      at_exit do
        puts "third handler code"
      end
    CODE

    status.success?.should be_true
    output.should eq <<-OUTPUT
                       third handler code
                       second handler code, explicit exit!
                       first handler code

                       OUTPUT
  end

  it "allows handlers to change the exit code with explicit `exit` call" do
    status, output = build_and_run <<-'CODE'
      at_exit do |exit_code|
        puts "first handler code, exit code: #{exit_code}"
      end

      at_exit do
        puts "second handler code, re-exiting"
        exit 42

        puts "not executed"
      end

      at_exit do |exit_code|
        puts "third handler code, exit code: #{exit_code}"
      end
    CODE

    status.success?.should be_false
    status.exit_code.should eq(42)
    output.should eq <<-OUTPUT
                       third handler code, exit code: 0
                       second handler code, re-exiting
                       first handler code, exit code: 42

                       OUTPUT
  end

  it "allows handlers to change the exit code with explicit `exit` call (2)" do
    status, output = build_and_run <<-'CODE'
      at_exit do |exit_code|
        puts "first handler code, exit code: #{exit_code}"
      end

      at_exit do
        puts "second handler code, re-exiting"
        exit 42

        puts "not executed"
      end

      at_exit do |exit_code|
        puts "third handler code, exit code: #{exit_code}"
      end

      exit 21
    CODE

    status.success?.should be_false
    status.exit_code.should eq(42)
    output.should eq <<-OUTPUT
                       third handler code, exit code: 21
                       second handler code, re-exiting
                       first handler code, exit code: 42

                       OUTPUT
  end

  it "changes final exit code when an handler raises an error" do
    status, output, error = build_and_run <<-'CODE'
      at_exit do |exit_code|
        puts "first handler code, exit code: #{exit_code}"
      end

      at_exit do
        puts "second handler code, raising"
        raise "Raised from at_exit handler!"

        puts "not executed"
      end

      at_exit do |exit_code|
        puts "third handler code, exit code: #{exit_code}"
      end
    CODE

    status.success?.should be_false
    status.exit_code.should eq(1)
    output.should eq <<-OUTPUT
                       third handler code, exit code: 0
                       second handler code, raising
                       first handler code, exit code: 1

                       OUTPUT
    error.should eq "Error running at_exit handler: Raised from at_exit handler!\n"
  end

  it "errors when used in an at_exit handler" do
    status, output, error = build_and_run <<-CODE
      at_exit do
        at_exit {}
      end
    CODE

    status.success?.should be_false
    error.should eq "Error running at_exit handler: Cannot use at_exit from an at_exit handler\n"
  end

  it "shows unhandled exceptions after at_exit handlers" do
    status, _, error = build_and_run <<-CODE
      at_exit do
        STDERR.puts "first handler code"
      end

      at_exit do
        STDERR.puts "second handler code"
      end

      raise "Kaboom!"
    CODE

    status.success?.should be_false
    error.should contain <<-OUTPUT
                           second handler code
                           first handler code
                           Unhandled exception: Kaboom!
                           OUTPUT
  end

  it "can get unhandled exception in at_exit handler" do
    status, _, error = build_and_run <<-CODE
      at_exit do |_, ex|
        STDERR.puts ex.try &.message
      end

      raise "Kaboom!"
    CODE

    status.success?.should be_false
    error.should contain <<-OUTPUT
                           Kaboom!
                           Unhandled exception: Kaboom!
                           OUTPUT
  end
end
