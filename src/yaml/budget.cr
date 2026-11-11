# :nodoc:
module YAML::Budget
  @events = 0
  @documents = 0
  @nodes = 0
  @aliases = 0
  @anchors = 0
  @depth = 0

  # memoize the cost in nodes and aliases of each anchor, so the counters
  # reflect the total number of reachables nodes through expanded aliases
  @anchor_scope = {} of Int32 => {String, Int32, Int32}
  @anchor_costs = {} of String => {Int32, Int32}

  protected def add_budget(kind : EventKind, anchor : String? = nil) : Nil
    add_event(1)

    case kind
    when EventKind::SCALAR
      add_node(1)
      add_anchor(1) if anchor
    when EventKind::SEQUENCE_START, EventKind::MAPPING_START
      add_node(1)
      add_depth(1)
      if anchor
        add_anchor(1)
        @anchor_scope[@depth] = {anchor, @nodes, @aliases}
      end
    when EventKind::SEQUENCE_END, EventKind::MAPPING_END
      if scope = @anchor_scope[@depth]?
        @anchor_scope.delete(@depth)
        anchor, nodes, aliases = scope
        @anchor_costs[anchor] = {@nodes - nodes, @aliases - aliases}
      end
      @depth -= 1
    when EventKind::ALIAS
      nodes, aliases = @anchor_costs[anchor]? || {1, 0}
      add_node(nodes)
      add_alias(aliases + 1)
    when EventKind::DOCUMENT_START
      add_document(1)
    end
  end

  private def add_event(count)
    if (@events += count) > @options.max_events
      raise "Exceeded maximum number of events"
    end
  end

  private def add_document(count)
    if (@documents += count) > @options.max_documents
      raise "Exceeded maximum number of documents"
    end
  end

  private def add_node(count)
    if (@nodes += count) > @options.max_nodes
      raise "Exceeded maximum number of nodes"
    end
  end

  private def add_alias(count)
    if (@aliases += count) > @options.max_aliases
      raise "Exceeded maximum number of aliases"
    end
    if @options.enforce_alias_anchor_ratio &&
       @aliases > @options.alias_anchor_min_aliases &&
       @aliases > @options.alias_anchor_multiplier * @anchors
      raise "Document contains excessive aliasing"
    end
  end

  private def add_anchor(count)
    if (@anchors += count) > @options.max_anchors
      raise "Exceeded maximum number of anchors"
    end
  end

  private def add_depth(count)
    if (@depth += count) > @options.max_nesting
      raise "Exceeded maximum depth"
    end
  end
end
