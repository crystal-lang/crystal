lib LibTcl("tcl")
  OK = 0x00_u32

  struct Interp
  end

  struct ObjType
  end

  struct Obj
    refCount : Int32
    bytes : UInt8*
    length : Int32
    typePtr : ObjType*
  end

  fun get_version = Tcl_GetVersion(major : Int32*, minor : Int32*, patch_level : Int32*, type : Int32*)
  fun create_interp = Tcl_CreateInterp() : Interp*

  fun new_boolean_obj = Tcl_NewBooleanObj(boolValue : Int32) : Obj*
  fun set_boolean_obj = Tcl_SetBooleanObj(objPtr : Obj*, boolValue : Int32)
  fun get_boolean_from_obj = Tcl_GetBooleanFromObj(interp : Interp*, objPtr : Obj*, boolPtr : Int32*) : Int32

  fun new_int_obj = Tcl_NewIntObj(intValue : Int32) : Obj*
  fun set_int_obj = Tcl_SetIntObj(objPtr : Obj*, intValue : Int32)
  fun get_int_from_obj = Tcl_GetIntFromObj(interp : Interp*, objPtr : Obj*, intPtr : Int32*) : Int32

  #   int
  # Tcl_ListObjAppendList(interp, listPtr, elemListPtr)
  # int
  # Tcl_ListObjAppendElement(interp, listPtr, objPtr)
  fun new_list_obj = Tcl_NewListObj(objc : Int32, objv : Obj**) : Obj*
  # Tcl_SetListObj(objPtr, objc, objv)
  # int
  # Tcl_ListObjGetElements(interp, listPtr, objcPtr, objvPtr)
  # int
  fun list_obj_length = Tcl_ListObjLength(interp : Interp*, listPtr : Obj*, intPtr : Int32*) : Int32
  # int
  # Tcl_ListObjIndex(interp, listPtr, index, objPtrPtr)
  # int
  # Tcl_ListObjReplace(interp, listPtr, first, count, objc, objv)
end
