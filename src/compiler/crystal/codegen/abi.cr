# Based on https://github.com/rust-lang/rust/blob/29ac04402d53d358a1f6200bea45a301ff05b2d1/src/librustc_trans/trans/cabi.rs
abstract class Crystal::ABI
  getter target_data : LLVM::TargetData
  getter? osx : Bool
  getter? windows : Bool

  def initialize(target_machine : LLVM::TargetMachine)
    @target_data = target_machine.data_layout
    triple = target_machine.triple
    @osx = !!(triple =~ /apple/)
    @windows = !!(triple =~ /windows/)
  end

  def self.from(target_machine : LLVM::TargetMachine) : self
    triple = target_machine.triple
    case triple
    when /x86_64.+windows-(?:msvc|gnu)/
      X86_Win64.new(target_machine)
    when /x86_64|amd64/
      X86_64.new(target_machine)
    when /i386|i486|i586|i686/
      X86.new(target_machine)
    when /aarch64|arm64/
      AArch64.new(target_machine)
    when /arm/
      ARM.new(target_machine)
    when /avr/
      AVR.new(target_machine, target_machine.cpu)
    when /wasm32/
      Wasm32.new(target_machine)
    else
      raise "Unsupported ABI for target triple: #{triple}"
    end
  end

  abstract def abi_info(atys : Array(LLVM::Type), rty : LLVM::Type, ret_def : Bool, context : LLVM::Context)
  abstract def size(type : LLVM::Type)
  abstract def align(type : LLVM::Type)

  def size(type : LLVM::Type, pointer_size) : Int32
    case type.kind
    when LLVM::Type::Kind::Integer
      (type.int_width + 7) // 8
    when LLVM::Type::Kind::Float
      4
    when LLVM::Type::Kind::Double
      8
    when LLVM::Type::Kind::Pointer
      pointer_size
    when LLVM::Type::Kind::Struct
      if type.packed_struct?
        type.struct_element_types.reduce(0) do |memo, elem|
          memo + size(elem)
        end
      else
        size = type.struct_element_types.reduce(0) do |memo, elem|
          align_offset(memo, elem) + size(elem)
        end
        align_offset(size, type)
      end
    when LLVM::Type::Kind::Array
      size(type.element_type) * type.array_size
    else
      raise "Unhandled LLVM::Type::Kind in size: #{type.kind}"
    end
  end

  def align_offset(offset, type) : Int32
    align = align(type)
    (offset + align - 1) // align * align
  end

  def align(type : LLVM::Type, pointer_size) : Int32
    case type.kind
    when LLVM::Type::Kind::Integer
      (type.int_width + 7) // 8
    when LLVM::Type::Kind::Float
      4
    when LLVM::Type::Kind::Double
      8
    when LLVM::Type::Kind::Pointer
      pointer_size
    when LLVM::Type::Kind::Struct
      if type.packed_struct?
        1
      else
        type.struct_element_types.reduce(1) do |memo, elem|
          Math.max(memo, align(elem))
        end
      end
    when LLVM::Type::Kind::Array
      align(type.element_type)
    else
      raise "Unhandled LLVM::Type::Kind in align: #{type.kind}"
    end
  end

  enum ArgKind
    Direct
    Indirect
    Ignore
  end

  struct ArgType
    getter kind : ArgKind
    getter type : LLVM::Type
    getter cast : LLVM::Type?
    getter pad : Nil
    getter attr : LLVM::Attribute?

    def self.direct(type, cast = nil, pad = nil, attr = nil)
      new ArgKind::Direct, type, cast, pad, attr
    end

    def self.indirect(type, attr) : self
      new ArgKind::Indirect, type, attr: attr
    end

    def self.ignore(type) : self
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
