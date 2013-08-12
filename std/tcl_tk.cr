lib LibTcl("tcl")
  struct Interp
  end

  struct AppInitProc
  end

  fun get_version = Tcl_GetVersion(major : Int32*, minor : Int32*, patch_level : Int32*, type : Void*)
  fun create_interp = Tcl_CreateInterp() : Interp*
end

lib LibTk("tk")
  fun init = Tk_Init(interp : LibTcl::Interp*) : Int32
  fun main_loop = Tk_MainLoop()
end
