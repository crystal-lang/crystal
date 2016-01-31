module DB
  module QueryMethods
    def query(query, *args)
      prepare(query).query(*args)
    end

    def query(query, *args)
      # CHECK prepare(query).query(*args, &block)
      query(query, *args).tap do |rs|
        begin
          yield rs
        ensure
          rs.close
        end
      end
    end

    def exec(query, *args)
      prepare(query).exec(*args)
    end

    def scalar(query, *args)
      prepare(query).scalar(*args)
    end

    def scalar(t, query, *args)
      prepare(query).scalar(t, *args)
    end

    def scalar?(query, *args)
      prepare(query).scalar?(*args)
    end

    def scalar?(t, query, *args)
      prepare(query).scalar?(t, *args)
    end
  end
end
