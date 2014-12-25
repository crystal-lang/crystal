class Crystal::Doc::Generator
  def initialize(@program, @base_dirs, @dir = "./doc")
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

  def generate_docs(types)
    copy_files
    generate_list types
    generate_types_docs types, @dir
  end

  def copy_files
    Dir.mkdir_p "#{@dir}/css"
    cp "index.html"
    cp "main.html"
    cp "css/style.css"
  end

  def cp(filename)
    `cp #{__DIR__}/html/#{filename} #{@dir}/#{filename}`
  end

  def generate_list(types)
    write_template "#{@dir}/list.html", ListTemplate.new(types)
  end

  def generate_types_docs(types, dir)
    types.each do |type|
      if type.program?
        filename = "#{dir}/toplevel.html"
      else
        filename = "#{dir}/#{type.name}.html"
      end

      write_template filename, TypeTemplate.new(type)

      next if type.program?

      subtypes = type.types
      if subtypes && !subtypes.empty?
        dirname = "#{dir}/#{type.name}"
        Dir.mkdir_p dirname
        generate_types_docs subtypes, dirname
      end
    end
  end

  def write_template(filename, template)
    File.open(filename, "w") do |file|
      io = BufferedIO.new(file)
      template.to_s io
      io.flush
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
      when Const, LibType
        next
      end

      types << type(type) if must_include? type
    end

    types.sort_by! &.name
  end
end
