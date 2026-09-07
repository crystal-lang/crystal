require "spec"
require "./spec_helper"

describe "`crystal spec`" do
  it "shows usage with --help" do
    Process.capture_result(crystal, "spec", "--help")
      .should(be_success)
      .output.should(contain("Usage: crystal spec"))
  end

  it "runs a spec file" do
    Process.capture_result(crystal, "spec", fixture_path("hello-world_spec.cr"))
      .should(be_success)
  end
end
