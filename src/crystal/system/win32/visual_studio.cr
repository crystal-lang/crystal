require "json"

module Crystal::System::VisualStudio
  struct Installation
    include JSON::Serializable

    @[JSON::Field(key: "installationPath")]
    getter directory : String

    @[JSON::Field(key: "installationVersion")]
    getter version : String

    # unused fields not mapped
  end

  def self.find_latest_msvc_path : String?
    # ported from https://github.com/microsoft/vswhere/wiki/Find-VC
    if vs_installations = get_vs_installations
      vs_installations.sort_by! &.version
      vs_installations.reverse_each do |installation|
        version_path = "#{installation.directory}\\VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt"
        next unless ::File.exists?(version_path)

        version = ::File.read(version_path).chomp
        next if version.empty?

        return ::Path["#{installation.directory}\\VC\\Tools\\MSVC\\#{version}"].normalize.to_s
      end
    end
  end

  private def self.get_vs_installations : Array(Installation)?
    if vswhere_path = find_vswhere
      vc_install_json = `#{::Process.quote(vswhere_path)} -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json`
      return unless $?.success? && !vc_install_json.empty?

      Array(Installation).from_json(vc_install_json)
    end
  end

  private def self.find_vswhere
    if crystal_path = ::Process.executable_path
      vswhere_path = "#{::File.dirname(crystal_path)}\\vswhere.exe"
      return vswhere_path if ::File.exists?(vswhere_path)
    end

    # standard path for VS2017 15.2 and later
    if program_files = ENV["ProgramFiles(x86)"]?
      vswhere_path = "#{program_files}\\Microsoft Visual Studio\\Installer\\vswhere.exe"
      return vswhere_path if ::File.exists?(vswhere_path)
    end

    ::Process.find_executable("vswhere.exe")
  end
end
