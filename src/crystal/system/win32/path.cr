require "c/combaseapi"
require "c/knownfolders"
require "c/shlobj_core"

module Crystal::System::Path
  def self.home : String
    if home_path = ENV["USERPROFILE"]?
      home_path
    elsif LibC.SHGetKnownFolderPath(pointerof(LibC::FOLDERID_Profile), 0, nil, out path_ptr) == 0
      home_path = String.from_utf16(path_ptr)[0]
      LibC.CoTaskMemFree(path_ptr)
      home_path
    else
      raise RuntimeError.from_winerror("SHGetKnownFolderPath")
    end
  end
end
