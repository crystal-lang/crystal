# Based on https://github.com/rust-lang/rust/blob/master/src/librustc_trans/trans/cabi.rs
abstract class LLVM::ABI
  getter target_data
  getter is_osx
  getter is_windows

  def initialize(target_machine : TargetMachine)
    @target_data = target_machine.data_layout
    triple = target_machine.triple
    @is_osx = !!(triple =~ /apple/)
    @is_windows = !!(triple =~ /windows/)
  end

  abstract def abi_info(atys : Array(Type), rty : Type, ret_def : Bool)
  abstract def size(type : Type)
  abstract def align(type : Type)

  enum ArgKind
    Direct
    Indirect
    Ignore
  end

  struct ArgType
    getter kind
    getter type
    getter cast
    getter pad
    getter attr

    def self.direct(type, cast = nil, pad = nil, attr = nil)
      new ArgKind::Direct, type, cast, pad, attr
    end

    def self.indirect(type, attr)
      new ArgKind::Indirect, type, attr: attr
    end

    def self.ignore(type)
      new ArgKind::Ignore, type
    end

    def initialize(@kind, @type, @cast = nil, @pad = nil, @attr = nil)
    end
  end

  class FunctionType
    getter arg_types
    getter return_type

    def initialize(@arg_types, @return_type)
    end
  end
end
