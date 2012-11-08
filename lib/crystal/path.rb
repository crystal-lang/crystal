module Crystal
  class Path
    attr_accessor :index
    attr_accessor :path

    def initialize(index, *path)
      @index = index
      @path = path
    end

    def with_index(other_index)
      Path.new(other_index, *path)
    end

    def append(other_path)
      other_path = other_path.path if other_path.is_a?(Path)
      Path.new(index, *(path + other_path))
    end

    def ==(other)
      other.is_a?(Path) && index == other.index && path == other.path
    end

    def evaluate_args(obj, args)
      types = obj.is_a?(Type) ? [nil, obj] : [nil]
      types += args.map &:type
      evaluate_types(types)
    end

    def evaluate_types(types)
      type = types[index]
      path.each do |ivar|
        type = type.lookup_instance_var(ivar).type
      end
      type
    end

    def hash
      @hash ||= begin
        hash = index.hash
        path.each do |piece|
          hash ^= piece.hash
        end
        hash
      end
    end

    def to_s
      str = "#{index}"
      str << '/' << path.join('/')
      str
    end
  end
end
