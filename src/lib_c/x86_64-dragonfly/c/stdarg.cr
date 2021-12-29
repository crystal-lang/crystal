lib LibC
  struct VaListTag
    gp_offset : UInt
    fp_offset : UInt
    overflow_arg_area : Void*
    reg_save_area : Void*
  end

  type VaList = VaListTag[1]
end
