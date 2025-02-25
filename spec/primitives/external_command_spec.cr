{% skip_file if flag?(:interpreted) %}

require "../support/tempfile"

describe "Crystal::Command" do
  it "exec external commands", tags: %w[slow] do
    with_temp_executable "crystal-external" do |command_path|
      compiler_path = File.expand_path(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "bin/crystal")

      with_tempfile "crystal-external.cr" do |source_file|
        File.write source_file, <<-CRYSTAL
          puts Process.find_executable("crystal")
          puts ENV["CRYSTAL_EXEC_PATH"]?
          puts PROGRAM_NAME
          puts ARGV
          CRYSTAL

        Process.run(compiler_path, ["build", source_file, "-o", command_path])
      end

      File.exists?(command_path).should be_true

      output = IO::Memory.new
      process = Process.new(compiler_path,
        ["external", "foo", "bar"],
        output: output, error: output,
        env: {"PATH" => {ENV["PATH"], File.dirname(command_path)}.join(Process::PATH_DELIMITER)}
      )

      status = process.wait
      status.success?.should be_true

      lines = output.to_s.lines
      lines.should eq [
        compiler_path,
        File.dirname(compiler_path),
        command_path,
        %(["foo", "bar"]),
      ]
    end
  end
end
