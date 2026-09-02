require "spec"
require "./spec_helper"

describe "GC" do
  it "aborts with an error message when an allocation is too large for the heap" do
    status, _, error = compile_and_run_source <<-CRYSTAL
      LibGC.set_max_heap_size(64_u64 * 1024 * 1024)
      GC.malloc(1_u64 << 30)
      CRYSTAL

    status.normal_exit?.should be_true
    status.exit_code.should eq(1)
    error.should contain("Out of memory: failed to allocate 1073741824 bytes")
  end

  it "aborts with an error message when the heap is exhausted" do
    status, _, error = compile_and_run_source <<-CRYSTAL
      LibGC.set_max_heap_size(32_u64 * 1024 * 1024)
      bufs = [] of Bytes
      loop do
        bufs << Bytes.new(1024 * 1024)
      end
      CRYSTAL

    status.normal_exit?.should be_true
    status.exit_code.should eq(1)
    error.should contain("Out of memory: failed to allocate")
  end

  it "compiles GC.stats" do
    typeof(GC.stats).should eq(GC::Stats)
  end

  it "raises if calling enable when not disabled" do
    expect_raises(Exception, "GC is not disabled") do
      GC.enable
    end
  end

  it ".stats" do
    GC.stats.should be_a(GC::Stats)
  end

  it ".prof_stats" do
    GC.prof_stats.should be_a(GC::ProfStats)
  end
end
