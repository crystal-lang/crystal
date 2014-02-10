lib LibTcl("tcl")
  OK = 0x00_u32

  NO_EVAL = 0x10000_u32
  EVAL_GLOBAL = 0x20000_u32
  EVAL_DIRECT = 0x40000_u32
  EVAL_INVOKE = 0x80000_u32

  struct Interp
  end

  struct ObjType
    name : UInt8*
  end

  struct Obj
    refCount : Int32
    bytes : UInt8*
    length : Int32
    typePtr : ObjType*
  end

  fun get_version = Tcl_GetVersion(major : Int32*, minor : Int32*, patch_level : Int32*, type : Int32*)
  fun create_interp = Tcl_CreateInterp() : Interp*

  fun get_obj_type = Tcl_GetObjType(typeName : UInt8*) : ObjType*

  fun new_boolean_obj = Tcl_NewBooleanObj(boolValue : Int32) : Obj*
  fun set_boolean_obj = Tcl_SetBooleanObj(objPtr : Obj*, boolValue : Int32)
  fun get_boolean_from_obj = Tcl_GetBooleanFromObj(interp : Interp*, objPtr : Obj*, boolPtr : Int32*) : Int32

  fun new_int_obj = Tcl_NewIntObj(intValue : Int32) : Obj*
  fun set_int_obj = Tcl_SetIntObj(objPtr : Obj*, intValue : Int32)
  fun get_int_from_obj = Tcl_GetIntFromObj(interp : Interp*, objPtr : Obj*, intPtr : Int32*) : Int32

  fun new_string_obj = Tcl_NewStringObj(bytes : UInt8*, length : Int32) : Obj*
  fun set_string_obj = Tcl_SetStringObj(objPtr : Obj*, bytes : UInt8*, length : Int32)
  fun get_string_from_obj = Tcl_GetStringFromObj(interp : Interp*, objPtr : Obj*, lengthPtr : Int32*) : UInt8*
  fun get_string = Tcl_GetString(objPtr : Obj*) : UInt8*
  # Tcl_StringObjAppend(interp, objPtr, bytes, length)
  # Tcl_StringObjAppendObj(interp, objPtr, srcPtr)

  # fun list_obj_append_list = Tcl_ListObjAppendList(interp : Interp*, listPtr : Obj*, elemListPtr : Obj*) : Int32
  fun list_obj_append_element = Tcl_ListObjAppendElement(interp : Interp*, listPtr : Obj*, objPtr : Obj*) : Int32
  fun new_list_obj = Tcl_NewListObj(objc : Int32, objv : Obj**) : Obj*
  # Tcl_SetListObj(objPtr, objc, objv)
  # int
  # Tcl_ListObjGetElements(interp, listPtr, objcPtr, objvPtr)
  # int
  fun list_obj_length = Tcl_ListObjLength(interp : Interp*, listPtr : Obj*, intPtr : Int32*) : Int32
  # int
  fun list_obj_index = Tcl_ListObjIndex(interp : Interp*, listPtr : Obj*, index : Int32, objPtrPtr : Obj**) : Int32
  # int
  # Tcl_ListObjReplace(interp, listPtr, first, count, objc, objv)

  fun append_all_obj_types = Tcl_AppendAllObjTypes(interp : Interp*, obj : Obj*) : Int32

  fun get_obj_result = Tcl_GetObjResult(interp : Interp*) : Obj*
  fun eval_ex = Tcl_EvalEx(interp : Interp*, script : UInt8*, numBytes : Int32, flags : UInt32) : Int32

end
