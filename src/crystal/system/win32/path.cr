require "c/combaseapi"
require "c/knownfolders"
require "c/shlobj_core"

module Crystal::System::Path
  def self.home : String
    ENV["USERPROFILE"]?.presence || known_folder_path(LibC::FOLDERID_Profile)
  end

  def self.known_folder_path(guid : LibC::GUID) : String
    if LibC.SHGetKnownFolderPath(pointerof(guid), 0, nil, out path_ptr) == 0
      path, _ = String.from_utf16(path_ptr)
      LibC.CoTaskMemFree(path_ptr)
      path
    else
      raise RuntimeError.from_winerror("SHGetKnownFolderPath")
    end
  end
end
