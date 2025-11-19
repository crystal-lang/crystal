module Reply
  class Search
    getter? open = false
    property query = ""
    getter? failed = false

    record SearchResult,
      index : Int32,
      result : Array(String),
      x : Int32,
      y : Int32

    def footer(io : IO, color : Bool)
      if open?
        io << "search: #{@query.colorize.toggle(failed? && color).bold.red}_"
        1
      else
        0
      end
    end

    def open
      @open = true
      @failed = false
    end

    def close
      @open = false
      @query = ""
      @failed = false
    end

    def search(history, from_index = history.index - 1)
      if search_result = search_up(history, @query, from_index: from_index)
        @failed = false
        history.go_to search_result.index
        return search_result
      end

      @failed = true
      history.set_to_last
      nil
    end

    private def search_up(history, query, from_index)
      return if query.empty?
      return unless 0 <= from_index < history.size

      # Search the history starting by `from_index` until first entry,
      # then cycle the search by searching from last entry to `from_index`
      from_index.downto(0).chain(
        (history.size - 1).downto(from_index + 1)
      ).each do |i|
        history.history[i].each_with_index do |line, y|
          x = line.index query
          return SearchResult.new(i, history.history[i], x, y) if x
        end
      end

      nil
    end
  end
end
