{% skip_file if flag?(:without_interpreter) %}

require "./spec_helper"
require "./repl_pty_spec_helper"

# These specs guard mid-session `require` in REPL mode (crystal-lang/crystal#12624
# and a REPL deadlock seen with C-binding requires): requiring a stdlib module
# that pulls C bindings (`digest/sha1` -> OpenSSL) after the prelude is loaded
# must return to a fresh prompt and the C calls must resolve.

private SHA1_ABC = "a9993e364706816aba3e25717850c26c9cd0d89d"

describe "REPL require mid-session" do
  it "require with C bindings after prelude (subprocess, stdin lines)" do
    executable = Process.executable_path || fail "can't find spec binary"
    input = IO::Memory.new(%(require "digest/sha1"\n) + %(Digest::SHA1.hexdigest("abc")))
    output = IO::Memory.new
    error = IO::Memory.new
    # "prelude" matches what the interactive `crystal i` loads.
    process = Process.new(executable, ["--interpret-repl", "prelude"],
      input: input, output: output, error: error)

    timed_out = false
    watchdog = spawn do
      sleep 60.seconds
      timed_out = true
      process.terminate rescue nil
    end
    status = process.wait

    unless status.success?
      fail "REPL subprocess failed (timed_out=#{timed_out}, status=#{status}):\n" \
           "stdout: #{output.rewind.gets_to_end.inspect[0...2000]}\n" \
           "stderr: #{error.rewind.gets_to_end.inspect[0...2000]}"
    end
    output.rewind.gets_to_end.should contain(SHA1_ABC)
  end

  it "require with C bindings after prelude (real REPL over a PTY)" do
    session = ReplPtySession.new(ReplPty.compiler_bin)
    begin
      session.read_until("initial prompt", "icr:1>", 30.seconds)
      session.submit(%(require "digest/sha1"))
      session.read_until("prompt after require", "icr:2>", 60.seconds)
      session.submit(%(Digest::SHA1.hexdigest("abc")))
      session.read_until("sha1 result", SHA1_ABC, 30.seconds)
    ensure
      session.close
    end
  end
end
