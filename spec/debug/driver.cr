repo_base_dir = "#{__DIR__}/../../"
tmp_build_dir = File.join(repo_base_dir, ".build")
Dir.mkdir_p(tmp_build_dir)

input = ARGV[0]

bin = File.join(tmp_build_dir, "debug_test_case")
debugger_script = File.join(tmp_build_dir, "./debugger.script")
lldb_crystal_formatters = File.expand_path(File.join(repo_base_dir, "etc", "lldb", "crystal_formatters.py"))

Process.run(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "#{repo_base_dir}/bin/crystal", ["build", "--debug", input, "-o", bin])

File.open(debugger_script, "w") do |script|
  script.puts "version"
  script.puts "command script import #{lldb_crystal_formatters}"

  # skip signals intentionally raised during GC initialization: https://hboehm.info/gc/debugging.html
  script.puts "breakpoint set -n main -G true -o true -C 'process handle -s false -n false SIGSEGV SIGBUS'"
  script.puts "breakpoint set -n __crystal_main -G true -o true -C 'process handle -s true -n true SIGSEGV SIGBUS'"

  script.puts "run"

  File.each_line(input) do |line|
    if md = line.match(/# lldb-command: (.*)/)
      script.puts md[1]
    elsif line.matches?(/\bdebugger\b/)
      script.puts "c"
    end
  end
end

session_output_dir = File.join(repo_base_dir, "tmp", "debug")
Dir.mkdir_p(session_output_dir)

session_log = File.join(session_output_dir, File.basename(input, File.extname(input)) + ".lldb-session")
session_assert = File.join(session_output_dir, File.basename(input, File.extname(input)) + ".lldb-assert")

File.open(session_assert, "w") do |assert|
  File.each_line(input) do |line|
    if md = line.match(/# lldb-command: (.*)/)
      assert.puts "CHECK: (lldb) #{md[1]}"
    elsif md = line.match(/# lldb-check: (.*)/)
      assert.puts "CHECK-NEXT: #{md[1]}"
    end
  end
end

`lldb -b --source #{debugger_script} #{bin} > #{session_log}`

llvm_version_suffix = File.basename(`#{__DIR__}/../../src/llvm/ext/find-llvm-config`).lchop("llvm-config")
`FileCheck#{llvm_version_suffix} #{session_assert} < #{session_log}`

exit $?.exit_code
