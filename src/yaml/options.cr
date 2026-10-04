struct YAML::Options
  # Maximum number of events allowed.
  property max_events : Int32 = 1_000_000

  # Maximum number of documents allowed.
  property max_documents : Int32 = 1_000

  # Maximum number of nodes (sequences + mappings + scalars) allowed.
  property max_nodes : Int32 = 250_000

  # Maximum number of aliases (`*ref`) allowed.
  property max_aliases : Int32 = 50_000

  # Maximum number of anchors (`&ref`) allowed.
  property max_anchors : Int32 = 50_000

  # Maximum structural depth (nested sequences and mappings) allowed.
  property max_nesting : Int32 = 1_000

  # If true, evaluates the alias/anchor ratio to avoid excessive expansion of
  # aliases.
  property enforce_alias_anchor_ratio : Bool = true

  # Minimum number of aliases required before starting to evaluate the
  # alias/anchor ratio. This avoids affecting smaller documents.
  property alias_anchor_min_aliases : Int32 = 100

  # The multiplier for the alias/anchor ratio evaluation. An error will be
  # raised when `aliases > multiplier * anchors` once `min_aliases` has been
  # reached.
  property alias_anchor_multiplier : Int32 = 10

  def initialize(*,
                 @max_events = 1_000_000,
                 @max_documents = 1_000,
                 @max_nodes = 250_000,
                 @max_aliases = 50_000,
                 @max_anchors = 50_000,
                 @max_nesting = 1_000,
                 @enforce_alias_anchor_ratio = true,
                 @alias_anchor_min_aliases = 100,
                 @alias_anchor_multiplier = 10)
  end
end
