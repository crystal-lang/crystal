require "spec"

describe Crystal::System do
  it "#effective_cpu_count" do
    # smoke test: must compile and must run
    Crystal::System.effective_cpu_count
  end
end
