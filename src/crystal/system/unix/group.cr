require "c/grp"

module Crystal::System::Group
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
    new(String.new(grp.gr_name), grp.gr_gid, extract_members(grp.gr_mem))
  end

  def from_name?(groupname : String)
    groupname.check_no_null_byte

    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    buf = Bytes.new(1024)

    ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrnam_r(groupname, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise Errno.new("getgrnam_r") if ret != 0
    return nil if grp_pointer.null?

    from_struct(grp)
  end

  def from_id?(groupid : LibC::GidT)
    grp = uninitialized LibC::Group
    grp_pointer = pointerof(grp)
    buf = Bytes.new(1024)

    ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    while ret == LibC::ERANGE
      buf = Bytes.new(buf.size * 2)
      ret = LibC.getgrgid_r(groupid, grp_pointer, buf, buf.size, pointerof(grp_pointer))
    end

    raise Errno.new("getgrgid_r") if ret != 0
    return nil if grp_pointer.null?

    from_struct(grp)
  end
end
