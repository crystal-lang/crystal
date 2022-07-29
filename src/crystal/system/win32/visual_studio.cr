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

  @@found_msvc = false

  @@msvc_path : ::Path?

  def self.find_latest_msvc_path : ::Path?
    if !@@found_msvc
      @@found_msvc = true
      @@msvc_path = find_latest_msvc_path_impl
    end

    @@msvc_path
  end

  private def self.find_latest_msvc_path_impl
    # ported from https://github.com/microsoft/vswhere/wiki/Find-VC
    # Copyright (C) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
    if vs_installations = get_vs_installations
      vs_installations.each do |installation|
        version_path = ::File.join(installation.directory, "VC", "Auxiliary", "Build", "Microsoft.VCToolsVersion.default.txt")
        next unless ::File.file?(version_path)

        version = ::File.read(version_path).chomp
        next if version.empty?

        return ::Path.new(installation.directory, "VC", "Tools", "MSVC", version)
      end
    end
  end

  private def self.get_vs_installations : Array(Installation)?
    if vswhere_path = find_vswhere
      vc_install_json = `#{::Process.quote(vswhere_path)} -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -products * -sort -format json`.chomp
      return if !$?.success? || vc_install_json.empty?

      Array(Installation).from_json(vc_install_json)
    end
  end

  private def self.find_vswhere
    # standard path for VS2017 15.2 and later
    if program_files = ENV["ProgramFiles(x86)"]?
      vswhere_path = ::File.join(program_files, "Microsoft Visual Studio", "Installer", "vswhere.exe")
      return vswhere_path if ::File.file?(vswhere_path)
    end

    ::Process.find_executable("vswhere.exe")
  end
end
