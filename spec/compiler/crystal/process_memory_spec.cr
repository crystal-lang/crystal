require "spec"
require "../../../src/compiler/crystal/process_memory"

describe Crystal::ProcessMemory do
  it "reports the memory the process uses" do
    memory = Crystal::ProcessMemory.current

    {% if flag?(:darwin) || flag?(:linux) || flag?(:win32) %}
      memory.should_not be_nil
      memory.not_nil!.should be > 0
    {% else %}
      memory.should be_nil
    {% end %}
  end
end
