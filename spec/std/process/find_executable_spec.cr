require "spec"
require "../../support/tempfile"

{% if flag?(:win32) %}
  FIND_EXECUTABLE_TEST_FILES = {
    [
      "inbase.exe",
      "not_exe",
      ".exe",
      "inboth.exe",

      "inbasebat.bat",
      "inbase.foo.exe",
      ".inbase.exe",

      "sub/insub.exe",
      "sub/not_exe",
      "sub/.exe",

      "../path/inpath.exe",
      "../path/not_exe",
      "../path/.exe",
      "../path/inboth.exe",
    ], [] of String,
  }

  def find_executable_test_cases(pwd)
    pwd_nodrive = "\\#{pwd.relative_to(pwd.anchor.not_nil!)}"
    {
      "inbase.exe"     => "inbase.exe",
      "inbase"         => "inbase.exe",
      "sub\\insub.exe" => "sub/insub.exe",
      "sub/insub"      => "sub/insub.exe",
      "inpath.exe"     => "../path/inpath.exe",
      "inpath"         => "../path/inpath.exe",
      "sub/.exe"       => "sub/.exe",
      "sub\\"          => "sub/.exe",
      "sub/"           => "sub/.exe",
      ".exe"           => ".exe",
      "not_exe"        => nil,
      "sub\\not_exe"   => nil,
      "inbasebat"      => nil,
      "inbase.foo.exe" => "inbase.foo.exe",
      "inbase.foo"     => nil,
      ".inbase.exe"    => ".inbase.exe",
      ".inbase"        => nil,
      ""               => nil,
      "."              => nil,
      "inboth.exe"     => "inboth.exe",
      "inboth"         => "inboth.exe",
      "./inbase"       => "inbase.exe",
      "../base/inbase" => "inbase.exe",
      "./inpath"       => nil,
      "sub"            => nil,
      "#{pwd}\\sub"    => nil,
      "#{pwd}\\sub\\"  => nil,
      # 'C:\Temp\base\inbase', 'C:\Temp\base\.exe', 'C:\Temp\base\'
      "#{pwd}\\inbase" => "inbase.exe",
      "#{pwd}\\.exe"   => ".exe",
      "#{pwd}\\"       => nil,
      # 'C:inbase', 'C:.exe', 'C:'
      "#{pwd.drive}inbase" => "inbase.exe",
      "#{pwd.drive}.exe"   => ".exe",
      "#{pwd.drive}"       => nil,
      "#{pwd.drive}sub\\"  => nil,
      # '\Temp\base\inbase', '\Temp\base\.exe', '\Temp\base\'
      "#{pwd_nodrive}\\inbase" => "inbase.exe",
      "#{pwd_nodrive}\\.exe"   => ".exe",
      "#{pwd_nodrive}\\"       => nil,
    }
  end
{% else %}
  FIND_EXECUTABLE_TEST_FILES = {
    [
      "inbase",
      "sub/insub",
      "../path/inpath",
    ], [
      "not_exe",
      "sub/not_exe",
      "../path/not_exe",
    ],
  }

  def find_executable_test_cases(pwd)
    {
      "./inbase"       => "inbase",
      "../base/inbase" => "inbase",
      "inbase"         => nil,
      "sub/insub"      => "sub/insub",
      "inpath"         => "../path/inpath",
      "./inpath"       => nil,
      "inbase/"        => nil,
      "sub/insub/"     => nil,
      "./not_exe"      => nil,
      "not_exe"        => nil,
      "sub/not_exe"    => nil,
      ""               => nil,
      "."              => nil,
      "#{pwd}/inbase"  => "inbase",
      "#{pwd}/inbase/" => nil,
      "#{pwd}/sub"     => nil,
      "./sub"          => nil,
      "sub"            => nil,
    }
  end
{% end %}

# TODO: Find a better way to execute specs involving file permissions when
# running as a privileged user. Compiling a program and running a separate
# process would be a lot of overhead.
private def pending_if_superuser!
  {% if flag?(:unix) %}
    if LibC.getuid == 0
      pending! "Spec cannot run as superuser"
    end
  {% end %}
end

describe "Process.find_executable" do
  test_dir = Path[SPEC_TEMPFILE_PATH] / "find_executable"
  base_dir = Path[test_dir] / "base"
  path_dir = Path[test_dir] / "path"

  around_all do |all|
    exe_names, non_exe_names = FIND_EXECUTABLE_TEST_FILES
    (exe_names + non_exe_names).each do |name|
      Dir.mkdir_p((base_dir / name).parent)
      File.write(base_dir / name, "")
    end
    exe_names.each do |name|
      File.chmod(base_dir / name, 0o755)
    end

    all.run

    FileUtils.rm_r(test_dir.to_s)
  end

  find_executable_test_cases(base_dir).each do |(command, exp)|
    if exp
      exp_path = File.expand_path(exp, base_dir)
      it "finds '#{command}' as '#{exp}'" do
        Process.find_executable(command, path: path_dir.to_s, pwd: base_dir).should eq exp_path
      end
    else
      it "fails to find '#{command}'" do
        Process.find_executable(command, path: path_dir.to_s, pwd: base_dir).should be_nil
      end
    end
  end

  it "raises ArgumentError for a name containing a null byte" do
    expect_raises(ArgumentError, "String contains null byte") do
      Process.find_executable("foo\0bar")
    end
  end

  {% if flag?(:unix) %}
    it "skips an inaccessible PATH entry" do
      pending_if_superuser!

      with_tempfile("inaccessible-path") do |denied_dir|
        Dir.mkdir_p(denied_dir)
        exe = File.join(denied_dir, "foo")
        File.write(exe, "")
        File.chmod(exe, 0o755)

        begin
          File.chmod(denied_dir, 0o000)

          expect_raises(File::AccessDeniedError) { File.info?(exe) }
          Process.find_executable("foo", path: denied_dir).should be_nil
        ensure
          File.chmod(denied_dir, 0o755)
        end
      end
    end

    it "finds an executable after an inaccessible PATH entry" do
      pending_if_superuser!

      with_tempfile("inaccessible-then-accessible", "accessible") do |denied_dir, allowed_dir|
        Dir.mkdir_p(denied_dir)
        Dir.mkdir_p(allowed_dir)

        denied_exe = File.join(denied_dir, "foo")
        File.write(denied_exe, "")
        File.chmod(denied_exe, 0o755)

        allowed_exe = File.join(allowed_dir, "foo")
        File.write(allowed_exe, "")
        File.chmod(allowed_exe, 0o755)

        begin
          File.chmod(denied_dir, 0o000)

          expect_raises(File::AccessDeniedError) { File.info?(denied_exe) }
          path = {denied_dir, allowed_dir}.join(Process::PATH_DELIMITER)
          Process.find_executable("foo", path: path).should eq allowed_exe
        ensure
          File.chmod(denied_dir, 0o755)
        end
      end
    end

    it "returns nil for an inaccessible absolute path" do
      pending_if_superuser!

      with_tempfile("inaccessible-absolute") do |denied_dir|
        Dir.mkdir_p(denied_dir)
        exe = File.join(denied_dir, "foo")
        File.write(exe, "")
        File.chmod(exe, 0o755)

        begin
          File.chmod(denied_dir, 0o000)

          expect_raises(File::AccessDeniedError) { File.info?(exe) }
          Process.find_executable(exe).should be_nil
        ensure
          File.chmod(denied_dir, 0o755)
        end
      end
    end
  {% end %}
end
