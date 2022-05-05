# Verifies that find_executable's specs match the behavior of Process.run.
# This doesn't actually test find_executable, only takes all the test cases
# directly from spec/std/process/find_executable_spec.cr and checks that
# *they* match what the OS actually does when finding an executable for the
# purpose of running it.

require "spec"
require "digest/sha1"
require "../support/env"
require "../support/tempfile"
require "../std/process/find_executable_spec"

describe "Process.run" do
  test_dir = Path[SPEC_TEMPFILE_PATH] / "manual_find_executable"
  base_dir = Path[test_dir] / "base"
  path_dir = Path[test_dir] / "path"

  around_all do |all|
    Dir.mkdir_p(test_dir)

    exe_names, non_exe_names = FIND_EXECUTABLE_TEST_FILES
    exe_names.each do |name|
      src_fn = test_dir / "self_printer.cr"
      exe_fn = test_dir / "self_printer.exe"
      File.write(src_fn, "print #{name.inspect}")
      Process.run(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "bin/crystal", ["build", "-o", exe_fn.to_s, src_fn.to_s])
      Dir.mkdir_p((base_dir / name).parent)
      File.rename(exe_fn, base_dir / name)
    end
    non_exe_names.each do |name|
      File.write(base_dir / name, "")
    end

    with_env "PATH": {ENV["PATH"], path_dir}.join(Process::PATH_DELIMITER) do
      Dir.cd(base_dir) do
        all.run
      end
    end

    FileUtils.rm_r(test_dir.to_s)
  end

  find_executable_test_cases(base_dir).each do |(command, exp)|
    if exp
      it "runs '#{command}' as '#{exp}'" do
        output = Process.run command, &.output.gets_to_end
        $?.success?.should be_true
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
