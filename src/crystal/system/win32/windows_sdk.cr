require "./windows_registry"

module Crystal::System::WindowsSDK
  REGISTRY_WIN10_SDK_64 = System.to_wstr %q(SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
  REGISTRY_WIN10_SDK_32 = System.to_wstr %q(SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)

  InstallationFolder = System.to_wstr "InstallationFolder"
  ProductVersion     = System.to_wstr "ProductVersion"

  def self.find_win10_sdk_libpath : ::Path?
    # ported from Common7\Tools\vsdevcmd\core\winsdk.bat (loaded by the MSVC
    # developer command prompt)
    {REGISTRY_WIN10_SDK_64, REGISTRY_WIN10_SDK_32}.each do |name|
      {LibC::HKEY_LOCAL_MACHINE, LibC::HKEY_CURRENT_USER}.each do |hkey|
        WindowsRegistry.open?(hkey, name) do |handle|
          installation_folder = WindowsRegistry.get_string(handle, InstallationFolder)
          product_version = WindowsRegistry.get_string(handle, ProductVersion)
          next unless installation_folder && product_version
          product_version = "#{product_version}.0"

          if ::File.file?(::File.join(installation_folder, "Include", product_version, "um", "winsdkver.h"))
            return ::Path.new(installation_folder, "Lib", product_version)
          end
        end
      end
    end
  end
end
