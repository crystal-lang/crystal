{% skip_file if flag?(:interpreted) %}

require "../spec_helper"

describe Crystal::Command do
  it "exec external commands", tags: %w[slow] do
    with_temp_executable "crystal-external" do |command_path|
      compiler_path = File.expand_path(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "bin/crystal")

      with_tempfile "crystal-external.cr" do |source_file|
        File.write source_file, <<-CRYSTAL
          puts Process.find_executable("crystal")
          puts PROGRAM_NAME
          puts ARGV

          exit 123
          CRYSTAL

        Process.run(compiler_path, ["build", source_file, "-o", command_path])
      end

      File.exists?(command_path).should be_true

      process = Process.new(compiler_path,
        ["external", "foo", "bar"],
        output: :pipe,
        env: {"PATH" => {ENV["PATH"], File.dirname(command_path)}.join(Process::PATH_DELIMITER)}
      )
      lines = process.output.gets_to_end.lines

      status = process.wait
      status.normal_exit?.should be_true
      status.exit_code.should eq 123

      lines.should eq [
        compiler_path,
        command_path,
        %(["foo", "bar"]),
      ]
    end
  end
end
