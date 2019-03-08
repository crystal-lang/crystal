{% if flag?(:openbsd) %}
  @[Link("c++abi")]
{% end %}
lib LibUnwind
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
    {% if flag?(:arm) %}
    FAILURE                  = 9
    {% end %}
  end

  alias Context = Void*

  {% if flag?(:arm) %}
    @[Flags]
    enum State
      VIRTUAL_UNWIND_FRAME  = 0
      UNWIND_FRAME_STARTING = 1
      UNWIND_FRAME_RESUME   = 2
      ACTION_MASK           = 3
      FORCE_UNWIND          = 8
      END_OF_STACK          = 16
    end

    enum UVRSC
      CORE = 0
      VFP = 1
      WMMXD = 3
      WMMXC = 4
    end

    enum UVRSD
      UINT32 = 0
      VFPX = 1
      UINT64 = 3
      FLOAT = 4
      DOUBLE = 5
    end

    enum UVRSR
      OK = 0,
      NOT_IMPLEMENTED = 1,
      FAILED = 2
    end

    # Unwinder cache, private fields for the unwinder's use
    struct ControlBlock_UnwinderCache
      reserved1 : UInt32 # init reserved1 to 0, then don't touch
      reserved2 : UInt32
      reserved3 : UInt32
      reserved4 : UInt32
      reserved5 : UInt32
    end

    # Propagation barrier cache (valid after phase 1):
    struct ControlBlock_BarrierCache
      sp : UInt32
      bitpattern : StaticArray(UInt32, 5)
    end

    # Cleanup cache (preserved over cleanup):
    struct ControlBlock_CleanupCache
      bitpattern : StaticArray(UInt32, 4)
    end

    # Personality routine cache (for personality routine's benefit):
    struct ControlBlock_PrCache
      fnstart : UInt32     # function start address
      ehtp : UInt32*       # pointer to EHT entry header word
      additional : UInt32  # additional data
      reserved1 : UInt32
    end

    struct ControlBlock
      exception_class : UInt64 #StaticArray(UInt8, 8)
      exception_cleanup : UInt32
      unwinder_cache : ControlBlock_UnwinderCache
      barrier_cache : ControlBlock_BarrierCache
      cleanup_cache : ControlBlock_CleanupCache
      pr_cache : ControlBlock_PrCache
      #__align : LibC::LongLong # Force alignment of next item to 8-byte boundary

      exception_object : UInt64
      exception_type_id : Int32
      __align : StaticArray(UInt8, 4)
    end

    alias Exception = ControlBlock

    fun backtrace = _Unwind_Backtrace((Context, Void*) -> ReasonCode, Void*) : Int32
    fun raise_exception = _Unwind_RaiseException(ucb : ControlBlock*) : ReasonCode
    fun vrs_get = _Unwind_VRS_Get(context : Context, regclass : UVRSC, regno : UInt32, representation : UVRSD, valuep : Void*) : UVRSR
    fun vrs_set = _Unwind_VRS_Set(context : Context, regclass : UVRSC, regno : UInt32, representation : UVRSD, valuep : Void*) : UVRSR
    fun __gnu_unwind_frame(ucb : ControlBlock*, context : Context) : ReasonCode
  {% else %}
    struct Exception
      exception_class : LibC::SizeT
      exception_cleanup : LibC::SizeT
      private1 : UInt64
      private2 : UInt64
      exception_object : UInt64
      exception_type_id : Int32
    end

    fun backtrace = _Unwind_Backtrace((Context, Void*) -> ReasonCode, Void*) : Int32
    fun get_language_specific_data = _Unwind_GetLanguageSpecificData(Context) : UInt8*
    fun get_region_start = _Unwind_GetRegionStart(Context) : LibC::SizeT
    fun get_ip = _Unwind_GetIP(context : Context) : LibC::SizeT
    fun set_ip = _Unwind_SetIP(context : Context, ip : LibC::SizeT) : LibC::SizeT
    fun set_gr = _Unwind_SetGR(context : Context, index : Int32, value : LibC::SizeT)
    fun raise_exception = _Unwind_RaiseException(ex : Exception*) : ReasonCode
  {% end %}

  {% if flag?(:x86_64) || flag?(:arm) || flag?(:aarch64) %}
    EH_REGISTER_0 = 0
    EH_REGISTER_1 = 1
  {% else %}
    EH_REGISTER_0 = 0
    EH_REGISTER_1 = 2
  {% end %}
end

{% if flag?(:arm) %}
  # ARM EHABI uses Virtual Scratch Register to snapshot registers. The following
  # methods emulate the `_Unwind_{Get|Set}IP` and `_Unwind_{Get|Set}GR` that can
  # be found on the X86 architectures.
  #
  # ARM EHABI also stores the function start and language specific data into the
  # exception object (`_Unwind_Control_Block`) whereas on X86 they are store on
  # the context instead. `libgcc` expects a pointer to the control block to be
  # stored by the personality routine in the R12 snapshot register for the
  # `_Unwind_GetRegionStart` and `_Unwind_GetLanguageSpecificData` to return the
  # correct data. Since extracting the data from the control block directly is
  # easy, we just do it.

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_unwind_get_gr(context : LibUnwind::Context, index : Int32) : UInt32
    value = 0_u32
    LibUnwind.vrs_get(context, LibUnwind::UVRSC::CORE, index.to_u32, LibUnwind::UVRSD::UINT32, pointerof(value).as(Void*))
    value
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_unwind_set_gr(context : LibUnwind::Context, index : Int32, value : UInt32) : Void
    LibUnwind.vrs_set(context, LibUnwind::UVRSC::CORE, index.to_u32, LibUnwind::UVRSD::UINT32, pointerof(value).as(Void*))
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_unwind_get_ip(context : LibUnwind::Context) : LibC::UInt
    # remove the thumb-bit before returning
    __crystal_unwind_get_gr(context, 15) & (~0x1_u32)
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_unwind_set_ip(context : LibUnwind::Context, ip : UInt32) : Void
    thumb_bit = __crystal_unwind_get_gr(context, 15) & (0x1_u32)
    __crystal_unwind_set_gr(context, 15, ip | thumb_bit)
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_get_region_start(ucb : LibUnwind::ControlBlock*) : UInt32
    ucb.value.pr_cache.fnstart
  end

  # :nodoc:
  @[AlwaysInline]
  fun __crystal_get_language_specific_data(ucb : LibUnwind::ControlBlock*) : UInt8*
    lsd = ucb.value.pr_cache.ehtp
    lsd += 1                                 # skip personality routine address
    lsd += (((lsd.value) >> 24) & 0xff) + 1  # skip unwind opcodes
    lsd.as(UInt8*)
  end
{% end %}
