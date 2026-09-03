module Reply
  SEARCH_ENTRIES = [
    [%(puts "Hello World")],
    [%(i = 0)],
    [
      %(while i < 10),
      %(  puts i),
      %(  i += 1),
      %(end),
    ],
    [%(pp! i)],
    [%("Bye")],
  ]

  describe Search do
    it "displays footer" do
      search = SpecHelper.search
      search.verify_footer("search: _", height: 1)

      search.query = "foo"
      search.verify_footer("search: foo_", height: 1)

      search.failed = true
      search.verify_footer("search: #{"foo".colorize.bold.red}_", height: 1)

      search.failed = false
      search.query = "foobar"
      search.verify_footer("search: foobar_", height: 1)

      search.close
      search.verify_footer("", height: 0)
    end

    it "opens and closes" do
      search = SpecHelper.search
      search.query = "foo"
      search.failed = true
      search.verify(query: "foo", open: true, failed: true)

      search.close
      search.verify(query: "", open: false, failed: false)

      search.query = "bar"
      search.failed = true

      search.open
      search.verify(query: "bar", open: true, failed: false)
    end

    it "searches" do
      search = SpecHelper.search
      history = SpecHelper.history(SEARCH_ENTRIES)

      search.search(history).should be_nil
      search.verify("", failed: true)
      history.verify(SEARCH_ENTRIES, index: 5)

      search.query = "p"
      search.search(history).should eq Search::SearchResult.new(3, [%(pp! i)], x: 0, y: 0)
      history.verify(SEARCH_ENTRIES, index: 3)

      search.query = "put"
      search.search(history).should eq Search::SearchResult.new(2, SEARCH_ENTRIES[2], x: 2, y: 1)
      history.verify(SEARCH_ENTRIES, index: 2)

      search.query = "i"
      search.search(history).should eq Search::SearchResult.new(1, ["i = 0"], x: 0, y: 0)
      history.verify(SEARCH_ENTRIES, index: 1)

      search.open
      search.search(history).should eq Search::SearchResult.new(3, ["pp! i"], x: 4, y: 0)
      history.verify(SEARCH_ENTRIES, index: 3)

      search.open
      search.search(history).should eq Search::SearchResult.new(2, SEARCH_ENTRIES[2], x: 2, y: 0)
      history.verify(SEARCH_ENTRIES, index: 2)

      search.query = "baz"
      search.search(history).should be_nil
      search.verify("baz", failed: true)
      history.verify(SEARCH_ENTRIES, index: 5)
    end
  end
end
