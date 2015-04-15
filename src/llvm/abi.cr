# Based on https://github.com/rust-lang/rust/blob/master/src/librustc_trans/trans/cabi.rs
module LLVM::ABI
  enum ArgKind
    Direct
    Indirect
    Ignore
  end

  class ArgType
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
