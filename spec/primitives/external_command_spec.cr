{% skip_file if flag?(:interpreted) %}

require "../support/tempfile"

describe "Crystal::Command" do
  it "exec external commands", tags: %w[slow] do
    with_temp_executable "crystal-external" do |path|
      with_tempfile "crystal-external.cr" do |source_file|
        File.write source_file, <<-CRYSTAL
          puts ENV["CRYSTAL"]?
          puts PROGRAM_NAME
          puts ARGV
          CRYSTAL

        Process.run(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "bin/crystal", ["build", source_file, "-o", path])
      end

      File.exists?(path).should be_true

      process = Process.new(ENV["CRYSTAL_SPEC_COMPILER_BIN"]? || "bin/crystal",
        ["external", "foo", "bar"],
        output: :pipe,
        env: {"PATH" => {ENV["PATH"], File.dirname(path)}.join(Process::PATH_DELIMITER)}
      )
      output = process.output.gets_to_end
      status = process.wait
      status.success?.should be_true
      lines = output.lines
      lines[0].should match /crystal/
      lines[1].should match /crystal-external/
      lines[2].should eq %(["foo", "bar"])
    end
  end
end
