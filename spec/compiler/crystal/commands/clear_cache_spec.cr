require "../../../spec_helper"

describe Crystal::Command do
  describe "clear_cache" do
    it "clears any cached compiler files" do
      file_path = File.tempname(dir: CacheDir.instance.dir)
      Dir.mkdir_p(File.dirname(file_path))
      File.touch(file_path)
      File.exists?(file_path).should be_true

      Crystal::Command.run(["clear_cache"])

      File.exists?(file_path).should be_false
      File.exists?(CacheDir.instance.dir).should be_false
    end
  end
end
