require "spec"
require "compiler/crystal/util"

describe Crystal do
  describe "normalize_path" do
    sep = {{ flag?(:win32) ? "\\" : "/" }}

    it { Crystal.normalize_path("a").should eq ".#{sep}a" }
    it { Crystal.normalize_path("./a/b").should eq ".#{sep}a#{sep}b" }
    it { Crystal.normalize_path("../a/b").should eq ".#{sep}..#{sep}a#{sep}b" }
    it { Crystal.normalize_path("/foo/bar").should eq "#{sep}foo#{sep}bar" }

    {% if flag?(:win32) %}
      it { Crystal.normalize_path("C:\\foo\\bar").should eq "C:\\foo\\bar" }
      it { Crystal.normalize_path("C:foo\\bar").should eq "C:foo\\bar" }
      it { Crystal.normalize_path("\\foo\\bar").should eq "\\foo\\bar" }
      it { Crystal.normalize_path("foo\\bar").should eq ".\\foo\\bar" }
    {% end %}
  end
end
