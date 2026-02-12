require "./spec_helper"
require "system"

describe System do
  describe "hostname" do
    # can't use backtick in interpreted code (#12241)
    pending_interpreted "returns current hostname" do
      shell_hostname = Process.capture!("hostname").strip

      hostname = System.hostname
      hostname.should eq(shell_hostname)
    end
  end

  describe "cpu_count" do
    # can't use backtick in interpreted code (#12241)
    pending_interpreted "returns current CPU count" do
      shell_cpus =
        {% if flag?(:win32) %}
          ENV["NUMBER_OF_PROCESSORS"].to_i
        {% elsif flag?(:unix) %}
          [
            {"getconf", ["_NPROCESSORS_ONLN"]},
            {"nproc", ["--all"]},
            {"grep", ["-sc", "^processor", "/proc/cpuinfo"]},
            {"sysctl", ["-n", "hw.cpu"]},
          ].find_value(0) do |(command, args)|
            process = Process.new(command, args, output: Process::Redirect::Pipe)
            output = process.output.gets_to_end
            output.to_i if process.wait.success?
          rescue IO::Error
            # silence unknown command errors
          end
        {% end %}

      System.cpu_count.should eq(shell_cpus)
    end
  end
end
