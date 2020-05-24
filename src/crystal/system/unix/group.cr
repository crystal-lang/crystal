require "c/grp"

module Crystal::System::Group
  private GETGR_R_SIZE_MAX = 1024 * 16

  private def from_struct(grp)
    new(String.new(grp.gr_name), grp.gr_gid.to_s)
  end

  private def from_name?(groupname : String)
    groupname.check_no_null_byte

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    initial_buf = uninitialized UInt8[1024]
    buf = initial_buf.to_slice

    ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE && buf.size < GETGR_R_SIZE_MAX
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise RuntimeError.from_errno("getgrnam_r") if ret != 0

    from_struct(grp) if grp_pointer
  end

  private def from_id?(groupid : String)
    groupid = groupid.to_u32?
    return unless groupid

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    initial_buf = uninitialized UInt8[1024]
    buf = initial_buf.to_slice

    ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE && buf.size < GETGR_R_SIZE_MAX
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise RuntimeError.from_errno("getgrgid_r") if ret != 0

    from_struct(grp) if grp_pointer
  end
end
