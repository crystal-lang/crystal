# Verifies that find_executable's specs match the behavior of Process.new
# This doesn't actually test find_executable, only takes all the test cases
# directly from spec/std/process/find_executable_spec.cr and checks that
# *they* match what the OS actually does when finding an executable for the
# purpose of running it.

require "spec"
require "digest/sha1"
require "../support/tempfile"
require "../std/process/find_executable_spec"

describe "Process.run" do
  test_dir = Path[SPEC_TEMPFILE_PATH] / "manual_find_executable"
  base_dir = Path[test_dir] / "base"
  path_dir = Path[test_dir] / "path"

  around_all do |all|
    Dir.mkdir_p(test_dir)

    exe_names, file_names = find_executable_test_files

    exe_names.map do |name|
      src = "print #{name.inspect}"
      digest = Digest::SHA1.hexdigest(src)
      src_fn = test_dir / "#{digest}.cr"
      exe_fn = test_dir / "#{digest}.exe"
      File.write(src_fn, src)
      {name, exe_fn, Process.new("crystal", ["build", "-o", exe_fn.to_s, src_fn.to_s])}
    end.each do |(name, exe_fn, process)|
      process.wait
      Dir.mkdir_p((base_dir / name).parent)
      File.rename(exe_fn, base_dir / name)
    end

    file_names.each do |name|
      File.write(base_dir / name, "")
    end

    old_path = ENV["PATH"]
    ENV["PATH"] += "#{Process::PATH_DELIMITER}#{path_dir}"
    Dir.cd(base_dir) do
      all.run
    end
    ENV["PATH"] = old_path

    FileUtils.rm_r(test_dir.to_s)
  end

  find_executable_test_cases(base_dir).each do |(command, exp)|
    if exp
      it "runs '#{command}' as '#{exp}'" do
        process = Process.new(command, output: Process::Redirect::Pipe)
        output = process.output.gets_to_end
        process.wait.success?.should be_true
        output.should eq exp
      end
    else
      it "fails to run '#{command}'" do
        expect_raises IO::Error do
          Process.run(command)
        end
      end
    end
  end
end
