{% skip unless flag?(:win32) %}
require "spec"
require "../std/spec_helper"

status = uninitialized Process::Status
output = ""
error = ""

it "at_exit handler runs for Ctrl+C" do
  sleep 1
  output.should eq(".Exiting")
  error.should be_empty
  status.success?.should be_false
end

Process.on_interrupt {
  Spec.run
  Process.on_interrupt {
    Spec.abort!
  }
}

status, output, error = compile_and_run_source <<-'CRYSTAL'


sleep
