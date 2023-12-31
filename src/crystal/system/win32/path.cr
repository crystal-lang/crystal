require "c/combaseapi"
require "c/knownfolders"
require "c/shlobj_core"

module Crystal::System::Path
  def self.home : String
    if home_path = ENV["USERPROFILE"]?.presence
      home_path
    else
      # TODO: interpreter doesn't implement pointerof(Path)` yet
      folderid = LibC::FOLDERID_Profile
      if LibC.SHGetKnownFolderPath(pointerof(folderid), 0, nil, out path_ptr) == 0
        home_path, _ = String.from_utf16(path_ptr)
        LibC.CoTaskMemFree(path_ptr)
        home_path
      else
        raise RuntimeError.from_winerror("SHGetKnownFolderPath")
      end
    end
  end
end
