class Crystal::Doc::Generator
  def initialize(@program, @base_dirs, @dir = "./docs")
  end

  def run
    `rm -rf #{@dir}`
    Dir.mkdir_p @dir

    types = collect_subtypes(@program)

    program_type = type(@program)
    if program_type.class_methods.any? { |method| must_include? method }
      types.insert 0, program_type
    end

    generate_docs types
  end

  def generate_docs(types, dir = @dir)
    types.each do |type|
      if type.program?
        filename = "#{dir}/toplevel.html"
      else
        filename = "#{dir}/#{type.name}.html"
      end

      File.open(filename, "w") do |file|
        io = BufferedIO.new(file)
        type.render io
        io.flush
      end

      next if type.program?

      subtypes = type.types
      if subtypes && !subtypes.empty?
        dirname = "#{dir}/#{type.name}"
        Dir.mkdir_p dirname
        generate_docs subtypes, dirname
      end
    end
  end

  def must_include?(type : Type)
    must_include? type.type
  end

  def must_include?(type : Crystal::Type)
    type.locations.any? do |type_location|
      must_include? type_location
    end
  end

  def must_include?(method : Method)
    must_include? method.def
  end

  def must_include?(a_def : Crystal::Def)
    must_include? a_def.location
  end

  def must_include?(location : Crystal::Location)
    case filename = location.filename
    when String
      @base_dirs.any? { |base_dir| filename.starts_with? base_dir }
    when VirtualFile
      must_include? filename.expanded_location
    else
      false
    end
  end

  def must_include?(nil : Nil)
    false
  end

  def type(type)
    Type.new(self, type)
  end

  def method(type)
    Method.new(self, type)
  end

  def collect_subtypes(parent)
    types = [] of Type

    parent.types.each_value do |type|
      case type
      when AliasType, Const, LibType
        next
      end

      types << type(type) if must_include? type
    end

    types.sort_by! &.name
  end
end
