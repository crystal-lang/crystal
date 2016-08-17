lib LibUnwind
  struct Exception
    exception_class : LibC::SizeT
    exception_cleanup : LibC::SizeT
    private1 : UInt64
    private2 : UInt64
    exception_object : UInt64
    exception_type_id : Int32
  end

  @[Flags]
  enum Action
    SEARCH_PHASE  =  1
    CLEANUP_PHASE =  2
    HANDLER_FRAME =  4
    FORCE_UNWIND  =  8
    END_OF_STACK  = 16
  end

  enum ReasonCode
    NO_REASON                = 0
    FOREIGN_EXCEPTION_CAUGHT = 1
    FATAL_PHASE2_ERROR       = 2
    FATAL_PHASE1_ERROR       = 3
    NORMAL_STOP              = 4
    END_OF_STACK             = 5
    HANDLER_FOUND            = 6
    INSTALL_CONTEXT          = 7
    CONTINUE_UNWIND          = 8
  end

  {% if flag?(:x86_64) %}
    EH_REGISTER_0 = 0
    EH_REGISTER_1 = 1
  {% else %}
    EH_REGISTER_0 = 0
    EH_REGISTER_1 = 2
  {% end %}

  alias Context = Void*

  fun raise_exception = _Unwind_RaiseException(ex : Exception*) : ReasonCode
  fun get_region_start = _Unwind_GetRegionStart(Context) : LibC::SizeT
  fun get_ip = _Unwind_GetIP(Context) : LibC::SizeT
  fun set_ip = _Unwind_SetIP(context : Context, ip : LibC::SizeT) : LibC::SizeT
  fun set_gr = _Unwind_SetGR(context : Context, index : Int32, value : LibC::SizeT)
  fun get_language_specific_data = _Unwind_GetLanguageSpecificData(Context) : UInt8*
  fun backtrace = _Unwind_Backtrace((Context, Void*) -> ReasonCode, Void*) : Int32
end
