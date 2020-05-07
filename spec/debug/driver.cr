def each_line1(file)
  File.read_lines(file).each_with_index do |line, index0|
    yield line, index0 + 1
  end
end

repo_base_dir = "#{__DIR__}/../../"
tmp_build_dir = File.join(repo_base_dir, ".build")
Dir.mkdir_p(tmp_build_dir)

input = ARGV[0]

bin = File.join(tmp_build_dir, "debug_test_case")
debugger_script = File.join(tmp_build_dir, "./debugger.script")

`#{repo_base_dir}/bin/crystal build --debug #{input} -o #{bin}`

File.open(debugger_script, "w") do |script|
  lldb_crystal_formatters = File.expand_path(File.join(repo_base_dir, "etc", "lldb", "crystal_formatters.py"))
  script.puts "version"
  script.puts "command script import #{lldb_crystal_formatters}"

  each_line1(input) do |line, line_number|
    if line.match(/# break\b/)
      script.puts "breakpoint set --file #{input} --line #{line_number}"
    end
  end

  script.puts "run"

  each_line1(input) do |line|
    if md = line.match(/# lldb-command: (.*)/)
      script.puts md[1]
    end
  end
end

session_output_dir = File.join(repo_base_dir, "tmp", "debug")
Dir.mkdir_p(session_output_dir)

session_log = File.join(session_output_dir, File.basename(input, File.extname(input)) + ".lldb-session")
session_assert = File.join(session_output_dir, File.basename(input, File.extname(input)) + ".lldb-assert")

File.open(session_assert, "w") do |assert|
  each_line1(input) do |line|
    if md = line.match(/# lldb-command: (.*)/)
      assert.puts "CHECK: (lldb) #{md[1]}"
    elsif md = line.match(/# lldb-check: (.*)/)
      assert.puts "CHECK-NEXT: #{md[1]}"
    end
  end
end

`/usr/bin/lldb -b --source #{debugger_script} #{bin} > #{session_log}`

`FileCheck #{session_assert} < #{session_log}`

exit $?.exit_code
