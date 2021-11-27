require "c/combaseapi"

lib LibC
  # Code taken from https://www.nuget.org/packages/Microsoft.VisualStudio.Setup.Configuration.Native/
  # The following is their license:
  #
  # The MIT License(MIT)
  # Copyright(C) Microsoft Corporation.All rights reserved.
  #
  # Permission is hereby granted, free of charge, to any person obtaining a copy
  # of this software and associated documentation files(the "Software"), to deal
  # in the Software without restriction, including without limitation the rights
  # to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
  # copies of the Software, and to permit persons to whom the Software is
  # furnished to do so, subject to the following conditions :
  #
  # The above copyright notice and this permission notice shall be included in
  # all copies or substantial portions of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
  # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  # FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  # IN THE SOFTWARE.

  struct ISetupInstanceVtbl
    queryInterface : ISetupInstance*, REFIID, Void** -> DWORD
    addRef : ISetupInstance* -> DWORD
    release : ISetupInstance* -> DWORD

    getInstanceId : ISetupInstance* -> DWORD
    getInstallDate : ISetupInstance*, FILETIME* -> DWORD
    getInstallationName : ISetupInstance*, BSTR* -> DWORD
    getInstallationPath : ISetupInstance*, BSTR* -> DWORD
    getInstallationVersion : ISetupInstance*, BSTR* -> DWORD
    getDisplayName : ISetupInstance*, LCID, BSTR* -> DWORD
    getDescription : ISetupInstance*, LCID, BSTR* -> DWORD
    resolvePath : ISetupInstance*, LPCOLESTR, BSTR* -> DWORD
  end

  struct ISetupInstance
    lpVtbl : ISetupInstanceVtbl*
  end

  struct IEnumSetupInstancesVtbl
    queryInterface : IEnumSetupInstances*, REFIID, Void** -> DWORD
    addRef : IEnumSetupInstances* -> DWORD
    release : IEnumSetupInstances* -> DWORD

    next : IEnumSetupInstances*, DWORD, ISetupInstance**, DWORD* -> DWORD
    skip : IEnumSetupInstances*, DWORD -> DWORD
    reset : IEnumSetupInstances* -> DWORD
    clone : IEnumSetupInstances*, IEnumSetupInstances** -> DWORD
  end

  struct IEnumSetupInstances
    lpVtbl : IEnumSetupInstancesVtbl*
  end

  struct ISetupConfigurationVtbl
    queryInterface : ISetupConfiguration*, REFIID, Void** -> DWORD
    addRef : ISetupConfiguration* -> DWORD
    release : ISetupConfiguration* -> DWORD

    enumInstances : ISetupConfiguration*, IEnumSetupInstances** -> DWORD
    getInstanceForCurrentProcess : ISetupConfiguration*, ISetupInstance** -> DWORD
    getInstanceForPath : ISetupConfiguration*, WCHAR*, ISetupInstance** -> DWORD
  end

  struct ISetupConfiguration
    lpVtbl : ISetupConfigurationVtbl*
  end

  CLSID_SetupConfiguration = GUID.new(0x177F0C4A, 0x1CD3, 0x4DE7, UInt8.static_array(0xA3, 0x2C, 0x71, 0xDB, 0xBB, 0x9F, 0xA3, 0x6D))
  IID_ISetupConfiguration  = GUID.new(0x42843719, 0xDB4C, 0x46C2, UInt8.static_array(0x8E, 0x7C, 0x64, 0xF1, 0x81, 0x6E, 0xFD, 0x5B))
end

private macro com_call(call)
  {{ call.receiver }}.value.lpVtbl.value.{{ call.name }}.call(
    {{ call.receiver }},
    {% for arg in call.args %} {{ arg }}, {% end %}
  )
end

module Crystal::System::VisualStudio
  record Installation, directory : String, version : Array(Int32)

  def self.find_latest_msvc_path : String?
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
    # inspired from https://github.com/ziglang/zig/blob/c9352ef9d6d9f1bca94c25710e11de0ae171605f/src/windows_sdk.cpp
    hr = LibC.CoInitializeEx(nil, LibC::COINIT_MULTITHREADED)
    return if hr != 0 && hr != 1

    hr = LibC.CoCreateInstance(pointerof(LibC::CLSID_SetupConfiguration), nil, LibC::CLSCTX_INPROC_SERVER, pointerof(LibC::IID_ISetupConfiguration), out setup_config)
    return if hr != 0

    installations = nil

    setup_config = setup_config.as(LibC::ISetupConfiguration*)
    begin
      all_instances = uninitialized LibC::IEnumSetupInstances*
      return unless com_call(setup_config.enumInstances(pointerof(all_instances))) == 0

      begin
        curr_instance = uninitialized LibC::ISetupInstance*
        while com_call(all_instances.next(1_u32, pointerof(curr_instance), Pointer(LibC::DWORD).null)) == 0
          begin
            bstr = uninitialized LibC::BSTR
            next unless com_call(curr_instance.getInstallationPath(pointerof(bstr))) == 0
            directory = acquire_bstr(bstr)

            next unless com_call(curr_instance.getInstallationVersion(pointerof(bstr))) == 0
            version = acquire_bstr(bstr).split('.').map(&.to_i)

            installations ||= [] of Installation
            installations << Installation.new(directory, version)
          ensure
            com_call curr_instance.release
          end
        end
      ensure
        com_call all_instances.release
      end
    ensure
      com_call setup_config.release
    end

    installations
  end

  private def self.acquire_bstr(bstr : LibC::BSTR)
    crystal_str = String.from_utf16(Slice.new(bstr, LibC.SysStringLen(bstr)))
    LibC.SysFreeString(bstr)
    crystal_str
  end
end
