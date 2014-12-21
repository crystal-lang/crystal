# Summary

* [Introduction](README.md)
* [Installation](installation/README.md)
   * [On Debian and Ubuntu](installation/on_debian_and_ubuntu.md)
   * [On RedHat and CentOS](installation/on_redhat_and_centos.md)
   * [On Mac OSX using Homebrew](installation/on_mac_osx_using_homebrew.md)
   * [From a tar.gz](installation/from_a_targz.md)
   * [From sources](installation/from_source_repository.md)
* [Overview](overview/README.md)
* [Syntax and semantics](syntax_and_semantics/README.md)
   * [Comments](syntax_and_semantics/comments.md)
   * [Local variables](syntax_and_semantics/local_variables.md)
   * [Global variables](syntax_and_semantics/global_variables.md)
       * [Thread local](syntax_and_semantics/thread_local.md)
   * [Assignment](syntax_and_semantics/assignment.md)
       * [Multiple assignment](syntax_and_semantics/multiple_assignment.md)
   * [Control expressions](syntax_and_semantics/control_expressions.md)
       * [Truthy and falsey values](syntax_and_semantics/truthy_and_falsey_values.md)
       * [if](syntax_and_semantics/if.md)
           * [As a suffix](syntax_and_semantics/as_a_suffix.md)
           * [As an expression](syntax_and_semantics/as_an_expression.md)
           * [Ternary if](syntax_and_semantics/ternary_if.md)
           * [if var](syntax_and_semantics/if_var.md)
           * [if var.is_a?(...)](syntax_and_semantics/if_varis_a.md)
           * [if var.responds_to?(...)](syntax_and_semantics/if_varresponds_to.md)
       * [unless](syntax_and_semantics/unless.md)
       * [case](syntax_and_semantics/case.md)
       * [while](syntax_and_semantics/while.md)
           * [break](syntax_and_semantics/break.md)
           * [next](syntax_and_semantics/next.md)
       * [until](syntax_and_semantics/until.md)
       * [&&](syntax_and_semantics/and.md)
       * [||](syntax_and_semantics/or.md)
   * [Types and methods](syntax_and_semantics/types_and_methods.md)
       * [Everything is an object](syntax_and_semantics/everything_is_an_object.md)
       * [The Program](syntax_and_semantics/the_program.md)
       * [Classes and methods](syntax_and_semantics/classes_and_methods.md)
           * [new, initialize and allocate](syntax_and_semantics/new,_initialize_and_allocate.md)
           * [Methods and instance variables](syntax_and_semantics/methods_and_instance_variables.md)
           * [Overloading](syntax_and_semantics/overloading.md)
           * [Default and named arguments](syntax_and_semantics/default_and_named_arguments.md)
           * [Type restrictions](syntax_and_semantics/type_restrictions.md)
           * [Visibility](syntax_and_semantics/visibility.md)
           * [Instace variables type inference](syntax_and_semantics/instace_variables_type_inference.md)
           * [Inheritance](syntax_and_semantics/inheritance.md)
               * [Virtual and abstract types](syntax_and_semantics/virtual_and_abstract_types.md)
           * [finalize](syntax_and_semantics/finalize.md)
       * [Modules](syntax_and_semantics/modules.md)
       * [Generics](syntax_and_semantics/generics.md)
       * [Structs](syntax_and_semantics/structs.md)
       * [Constants](syntax_and_semantics/constants.md)
       * Blocks, functions and closures
           * Function literal
           * Function pointer
       * [alias](syntax_and_semantics/alias.md)
   * Type reflection
       * [is_a?](syntax_and_semantics/is_a.md)
       * responds_to?
       * as
       * typeof
   * Attributes
       * @[ThreadLocal]
       * @[Packed]
       * @[AlwaysInline]
       * @[NoInline]
       * @[ReturnsTwice]
       * [@[Raises]]([raises])
   * [Requiring files](syntax_and_semantics/requiring_files.md)
   * Low-level primitives
       * pointerof
       * sizeof
       * instance_sizeof
       * declare var
   * Exception handling
   * [Compile-time flags](syntax_and_semantics/compile_time_flags.md)
       * [Cross-compilation](syntax_and_semantics/cross-compilation.md)
   * [Macros](syntax_and_semantics/macros.md)
       * [Macro methods](syntax_and_semantics/macro_methods.md)
   * [C bindings](syntax_and_semantics/c_bindings/README.md)
       * [lib](syntax_and_semantics/c_bindings/lib.md)
       * [fun](syntax_and_semantics/c_bindings/fun.md)
           * [out](syntax_and_semantics/c_bindings/out.md)
           * [to_unsafe](syntax_and_semantics/c_bindings/to_unsafe.md)
       * [struct](syntax_and_semantics/c_bindings/struct.md)
       * [union](syntax_and_semantics/c_bindings/union.md)
       * [enum](syntax_and_semantics/c_bindings/enum.md)
       * [Variables](syntax_and_semantics/c_bindings/variables.md)
       * [Constants](syntax_and_semantics/c_bindings/constants.md)
       * [type](syntax_and_semantics/c_bindings/type.md)
       * [alias](syntax_and_semantics/c_bindings/alias.md)
       * [Callbacks](syntax_and_semantics/c_bindings/callbacks.md)
* [Built-in types](builtin_types/README.md)
   * [Nil](builtin_types/nil.md)
   * [Bool](builtin_types/bool.md)
   * [Integer types](builtin_types/integer_types.md)
   * [Floating point types](builtin_types/floating_point_types.md)
   * [Char](builtin_types/char.md)
   * String
   * [Symbol](builtin_types/symbol.md)
   * [Reference](builtin_types/reference.md)
   * [Value](builtin_types/value.md)
   * [Struct](builtin_types/struct.md)
   * [Pointer](builtin_types/pointer.md)
   * StaticArray
   * Tuple
   * Range
   * Array
   * Hash
   * Regex

