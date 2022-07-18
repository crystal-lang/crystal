require "string_pool"

module Crystal
  struct IdentPool
    getter string_pool : StringPool

    def initialize(@string_pool : StringPool = StringPool.new)
    end

    def get(string : String) : Ident
      Ident.new(@string_pool.get(string.to_slice))
    end

    def get(slice : Bytes) : Ident
      Ident.new(@string_pool.get(slice.to_unsafe, slice.size))
    end

    def get(str : UInt8*, len) : Ident
      Ident.new(@string_pool.get(str, len))
    end

    {% for name, value in {
                            :empty             => "",
                            :underscore        => "_",
                            :brackets          => "[]",
                            :brackets_question => "[]?",
                            :brackets_equal    => "[]=",
                            :dollar_tilde      => "$~",
                            :dollar_question   => "$?",
                            :tilde             => "~",
                            :arrow             => "->",
                            :plus              => "+",
                            :minus             => "-",
                            :amp_plus          => "&+",
                            :amp_minus         => "&-",
                            :star              => "*",
                            :amp_star          => "&*",
                            :star_star         => "**",
                            :slash             => "/",
                            :slash_slash       => "//",
                            :backtick          => "`",
                            :bang              => "!",
                            :at_type           => "@type",
                            :at_top_level      => "@top_level",
                            :at_def            => "@def",
                            :nil_var_name      => "<nil_var>",
                            :cmp_let           => "<=",
                            :cmp_lt            => "<",
                            :cmp_get           => ">=",
                            :cmp_gt            => ">",
                            :cmp_eq            => "==",
                            :cmp_ne            => "!=",
                            :cmp_case_eq       => "===",
                            :pipe_pipe         => "||",
                            :amp_amp           => "&&",
                            :shift_left        => "<<",
                            :shift_right       => ">>",
                            :hat               => "^",
                            :pipe              => "|",
                            :amp               => "&",
                            :percent           => "%",
                            :percent_scope     => "%scope",
                            :percent_self      => "%self",
                          } %}
      getter({{name.id}} : Ident) { get {{value}} }
    {% end %}

    {% for name in %w(
                     All
                     Array
                     Bool
                     Channel
                     Char
                     Enumerable
                     Fiber
                     Flags
                     Float32
                     Float64
                     GC
                     Hash
                     IndexError
                     Int128
                     Int16
                     Int32
                     Int64
                     Int8
                     N
                     NamedTuple
                     Nil
                     NoReturn
                     None
                     Options
                     Pointer
                     Primitive
                     R
                     Range
                     Regex
                     StaticArray
                     String
                     Symbol
                     T
                     Tuple
                     TypeCastError
                     UInt128
                     UInt16
                     UInt32
                     UInt64
                     UInt8
                     Union
                     Void
                     add_finalizer
                     allocate
                     allocate
                     argc
                     argv
                     as
                     as?
                     atomicrmw
                     binary
                     call
                     class
                     class
                     class_crystal_instance_type_id
                     cmpxchg
                     compare_versions
                     concat
                     const
                     convert
                     debug
                     each
                     element_type
                     enum_new
                     enum_new
                     enum_value
                     enum_value
                     env
                     extended
                     external_var_get
                     external_var_get
                     external_var_set
                     external_var_set
                     fdiv
                     fence
                     file_exists?
                     finalize
                     finished
                     flag?
                     format
                     framework
                     host_flag?
                     included
                     includes?
                     inherited
                     initialize
                     initialize
                     inspect
                     instance_sizeof
                     interpolation
                     interpreter_call_stack_unwind
                     interpreter_current_fiber
                     interpreter_fiber_swapcontext
                     interpreter_intrinsics_bitreverse16
                     interpreter_intrinsics_bitreverse32
                     interpreter_intrinsics_bitreverse64
                     interpreter_intrinsics_bswap16
                     interpreter_intrinsics_bswap32
                     interpreter_intrinsics_countleading128
                     interpreter_intrinsics_countleading16
                     interpreter_intrinsics_countleading32
                     interpreter_intrinsics_countleading64
                     interpreter_intrinsics_countleading8
                     interpreter_intrinsics_counttrailing128
                     interpreter_intrinsics_counttrailing16
                     interpreter_intrinsics_counttrailing32
                     interpreter_intrinsics_counttrailing64
                     interpreter_intrinsics_counttrailing8
                     interpreter_intrinsics_debugtrap
                     interpreter_intrinsics_memcpy
                     interpreter_intrinsics_memmove
                     interpreter_intrinsics_memset
                     interpreter_intrinsics_pause
                     interpreter_intrinsics_popcount128
                     interpreter_intrinsics_popcount16
                     interpreter_intrinsics_popcount32
                     interpreter_intrinsics_popcount64
                     interpreter_intrinsics_popcount8
                     interpreter_intrinsics_read_cycle_counter
                     interpreter_libm_ceil_f32
                     interpreter_libm_ceil_f64
                     interpreter_libm_copysign_f32
                     interpreter_libm_copysign_f64
                     interpreter_libm_cos_f32
                     interpreter_libm_cos_f64
                     interpreter_libm_exp2_f32
                     interpreter_libm_exp2_f64
                     interpreter_libm_exp_f32
                     interpreter_libm_exp_f64
                     interpreter_libm_floor_f32
                     interpreter_libm_floor_f64
                     interpreter_libm_log10_f32
                     interpreter_libm_log10_f64
                     interpreter_libm_log2_f32
                     interpreter_libm_log2_f64
                     interpreter_libm_log_f32
                     interpreter_libm_log_f64
                     interpreter_libm_max_f32
                     interpreter_libm_max_f64
                     interpreter_libm_min_f32
                     interpreter_libm_min_f64
                     interpreter_libm_pow_f32
                     interpreter_libm_pow_f64
                     interpreter_libm_powi_f32
                     interpreter_libm_powi_f64
                     interpreter_libm_rint_f32
                     interpreter_libm_rint_f64
                     interpreter_libm_round_f32
                     interpreter_libm_round_f64
                     interpreter_libm_sin_f32
                     interpreter_libm_sin_f64
                     interpreter_libm_sqrt_f32
                     interpreter_libm_sqrt_f64
                     interpreter_libm_trunc_f32
                     interpreter_libm_trunc_f64
                     interpreter_raise_without_backtrace
                     interpreter_spawn
                     is_a?
                     ldflags
                     lib
                     load_atomic
                     main
                     malloc
                     method_added
                     method_missing
                     new
                     nil?
                     non_blocking_select
                     none?
                     not_nil!
                     null
                     object_crystal_type_id
                     object_id
                     offsetof
                     out
                     p
                     p!
                     parse_type
                     pkg_config
                     pointer_add
                     pointer_address
                     pointer_diff
                     pointer_get
                     pointer_malloc
                     pointer_malloc
                     pointer_new
                     pointer_new
                     pointer_realloc
                     pointer_set
                     pointer_set
                     pointerof
                     pp
                     pp!
                     previous_def
                     proc_call
                     puts
                     raise
                     read_file
                     read_file?
                     responds_to?
                     run
                     select
                     self
                     self?
                     size
                     sizeof
                     skip_file
                     static
                     store_atomic
                     struct_or_union_set
                     struct_or_union_set
                     super
                     symbol_to_s
                     system
                     throw_info
                     to_unsafe
                     tuple_indexer_known_index
                     typeof
                     unchecked_convert
                     unchecked_convert
                     union
                     unsafe_build
                     unsafe_div
                     unsafe_mod
                     unsafe_shl
                     unsafe_shr
                     va_arg
                     value
                     x) %}
      {% ivar_name = if name.ends_with?("?")
                       "#{name[0...-1].id}_question"
                     elsif name.ends_with?("!")
                       "#{name[0...-1].id}_bang"
                     else
                       name
                     end %}

      @@_{{ivar_name.id}} : Ident?

      def _{{name.id}} : Ident
        @@_{{ivar_name.id}} ||= get({{name}})
      end
    {% end %}
  end
end
