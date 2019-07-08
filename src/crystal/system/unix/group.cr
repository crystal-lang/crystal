require "c/grp"

module Crystal::System::Group
  private GETGR_R_SIZE_MAX = 1024 * 16

  private def extract_members(gr_mem)
    members = Array(String).new

    n = 0
    while gr_mem[n]
      members << String.new(gr_mem[n])
      n += 1
    end

    members
  end

  private def from_struct(grp)
    new(String.new(grp.gr_name), grp.gr_gid.to_s, extract_members(grp.gr_mem))
  end

  def from_name?(groupname : String)
    groupname.check_no_null_byte

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    initial_buf = Bytes.new(1024)
    buf = initial_buf.to_slice

    ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE && buf.size < GETGR_R_SIZE_MAX
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise Errno.new("getgrnam_r") if ret != 0

    from_struct(grp) if grp_pointer
  end

  def from_id?(groupid : String)
    groupid = groupid.to_i.to_u32!
    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    initial_buf = Bytes.new(1024)
    buf = initial_buf.to_slice

    ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE && buf.size < GETGR_R_SIZE_MAX
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise Errno.new("getgrgid_r") if ret != 0

    from_struct(grp) if grp_pointer
  end
end
