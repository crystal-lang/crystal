require "c/grp"
require "../unix"

module Crystal::System::Group
  private GETGR_R_SIZE_MAX = 1024 * 16

  def initialize(@name : String, @id : String)
  end

  def system_name
    @name
  end

  def system_id
    @id
  end

  private def self.from_struct(grp)
    ::System::Group.new(String.new(grp.gr_name), grp.gr_gid.to_s)
  end

  def self.from_name?(groupname : String)
    groupname.check_no_null_byte

    grp = uninitialized LibC::Group
    grp_pointer = Pointer(LibC::Group).null
    System.retry_with_buffer("getgrnam_r", GETGR_R_SIZE_MAX) do |buf|
      LibC.getgrnam_r(groupname, pointerof(grp), buf, buf.size, pointerof(grp_pointer)).tap do
        # It's not necessary to check success with `ret == 0` because `grp_pointer` will be NULL on failure
        return from_struct(grp) if grp_pointer
      end
    end
  end

  def self.from_id?(groupid : String)
    groupid = groupid.to_u32?
    return unless groupid

    grp = uninitialized LibC::Group
    grp_pointer = Pointer(LibC::Group).null
    System.retry_with_buffer("getgrgid_r", GETGR_R_SIZE_MAX) do |buf|
      LibC.getgrgid_r(groupid, pointerof(grp), buf, buf.size, pointerof(grp_pointer)).tap do
        # It's not necessary to check success with `ret == 0` because `grp_pointer` will be NULL on failure
        return from_struct(grp) if grp_pointer
      end
    end
  end
end
