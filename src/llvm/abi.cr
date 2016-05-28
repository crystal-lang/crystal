# Based on https://github.com/rust-lang/rust/blob/master/src/librustc_trans/trans/cabi.rs
abstract class LLVM::ABI
  getter target_data : TargetData
  getter? osx : Bool
  getter? windows : Bool

  def initialize(target_machine : TargetMachine)
    @target_data = target_machine.data_layout
    triple = target_machine.triple
    @osx = !!(triple =~ /apple/)
    @windows = !!(triple =~ /windows/)
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
    getter kind : ArgKind
    getter type : Type
    getter cast : Type?
    getter pad : Nil
    getter attr : Attribute?

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
    getter arg_types : Array(ArgType)
    getter return_type : ArgType

    def initialize(@arg_types, @return_type)
    end
  end
end
