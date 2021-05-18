require "./properties"

module String::Grapheme
  # Unicode extended grapheme cluster. `Graphemes` Iterator will return an instance of this struct to return information about specific grapheme cluster.
  struct Cluster
    # Returns codepoints which corresponds to the current grapheme cluster.
    getter codepoints : Array(Int32)
    # returns the interval of the current grapheme as byte positions into the
    # original string. The first returned value "from" indexes the first byte
    # and the second retured value "to" indexes the first byte that is not included
    # anumore, i.e. `str[from...to]` is the current grapheme cluster of
    # the original string "str".
    getter positions : Tuple(Int32, Int32)

    # :nodoc:
    def initialize(@codepoints, @positions)
    end

    # returns a substring of the original string which corresponds to the current grapheme cluster
    def str
      @codepoints.map(&.chr).join
    end

    def to_s(io : IO) : Nil
      io << str
    end

    # returns a byte slice which corresponds to the current grapheme cluster.
    def bytes
      str.to_slice
    end
  end

  # Graphemes implements an iterator over Unicode extended grapheme clusters,
  # specified in the Unicode Standard Annex #29. Grapheme clusters correspond to
  # "user-perceived characters". These characters often consist of multiple
  # code points (e.g. the "woman kissing woman" emoji consists of 8 code points:
  # woman + ZWJ + heavy black heart (2 code points) + ZWJ + kiss mark + ZWJ +
  # woman) and the rules described in Annex #29 must be applied to group those
  # code points into clusters perceived by the user as one character.
  struct Graphemes
    include Iterator(Cluster)

    def initialize(str : String)
      @codepoints = Array(Int32).new(str.size)
      @indices = Array(Int32).new(str.size + 1)
      @start = 0
      @end = 0
      @pos = 0
      @state = State::Any
      str.each_char_with_index do |c, i|
        @codepoints << c.ord
        @indices << str.char_index_to_byte_index(i).not_nil!
      end
      @indices << str.bytesize
      move_next # Parse ahead
    end

    def next
      return stop unless move_next
      Cluster.new(@codepoints[@start...@end], {@indices[@start], @indices[@end]})
    end

    # Reset puts the iterator into its initial state such that the next call to
    # `next()` sets it to the first grapheme cluster again.
    def reset : Nil
      @start, @end, @pos, @state = 0, 0, 0, State::Any
      move_next
    end

    # advances the iterator by one grapheme cluster and returns false if no
    # cluster are left. This function must be called before the first cluster is
    # accessed
    private def move_next
      @start = @end

      # The state transition gives us a boundary instruction BEFORE the next code point
      # so we always need to stay ahead by one code point.

      # parse the next code point.
      while @pos <= @codepoints.size
        # GB2
        if @pos == @codepoints.size
          @end = @pos
          @pos += 1
          break
        end

        # Determine the property of the next character.
        next_prop = Property.from(@codepoints[@pos])
        @pos += 1

        # Find the applicable transition
        if (transition = @transitions[{@state, next_prop}]?)
          # We have a specific transition. We'll use it
          @state = transition[0]
          boundary = transition[1] == Instruction::Boundary
        else
          # No specific transition found. Try the less specific ones.
          if (trans_any_prop = @transitions[{@state, Property::Any}]?) &&
             (trans_any_state = @transitions[{State::Any, next_prop}]?)
            # Both apply. We'll use a mix (see comments for `Transitions`)
            @state = trans_any_state[0]
            boundary = trans_any_state[1] == Instruction::Boundary
            if trans_any_prop[2] < trans_any_state[2]
              @state = trans_any_prop[0]
              boundary = trans_any_prop[1] == Instruction::Boundary
            end
          elsif trans_any_prop = @transitions[{@state, Property::Any}]?
            # We only have a spefic state.
            @state = trans_any_prop[0]
            boundary = trans_any_prop[1] == Instruction::Boundary
            # This branch will propbably never be reached because trans_any_state
            # will always be true given the current transition map. But we keep it here
            # for future modifications to the transition map where this may not be true anymore.
          elsif trans_any_state = @transitions[{State::Any, next_prop}]?
            # we only have a specific property
            @state = trans_any_state[0]
            boundary = trans_any_state[1] == Instruction::Boundary
          else
            # No known transition. GB999: Any x Any
            @state = State::Any
            boundary = true
          end
        end

        # If we found a cluster boundary, let's stop here. The current cluster will
        # be the one that just ended.
        if @pos - 1 == 0 || boundary
          @end = @pos - 1
          break
        end
      end
      @start != @end
    end

    # State::apheme cluster parser states
    private enum State
      Any
      CR
      ControlLF
      L
      LVV
      LVTT
      Prepend
      ExtendedPictographic
      ExtendedPictographicZWJ
      RIOdd
      RIEven
    end

    # State::apheme cluster parser's breaking instructions.
    private enum Instruction
      NoBoundary
      Boundary
    end

    # Grapheme cluster parser's state transitions. Maps {State, Property} to
    # {State, Instruction, Rule number}. The breaking instruction always refers to
    # the boundary between the last and the next code point.
    #
    # This Hash is required as follows:
    #
    #   1. Find specific state + specific property. Stop if found.
    #   2. Find specific state + any property.
    #   3. Find any state + specific property.
    #   4. If only (2) or (3) (but not both) was found, stop.
    #   5. If both (2) and (3) were found, use state and breaking instruction from
    #      the transition with the lower rule number, prefer (3) if rule numbers
    #      are equal. Stop.
    #   6. Assume `State::Any` and `Instruction::Boundary`.
    @transitions = {
      # GB5
      {State::Any, Property::CR}      => {State::CR, Instruction::Boundary, 50},
      {State::Any, Property::LF}      => {State::ControlLF, Instruction::Boundary, 50},
      {State::Any, Property::Control} => {State::ControlLF, Instruction::Boundary, 50},

      # GB4
      {State::CR, Property::Any}        => {State::Any, Instruction::Boundary, 40},
      {State::ControlLF, Property::Any} => {State::Any, Instruction::Boundary, 40},

      # GB3.
      {State::CR, Property::LF} => {State::Any, Instruction::NoBoundary, 30},

      # GB6.
      {State::Any, Property::L} => {State::L, Instruction::Boundary, 9990},
      {State::L, Property::L}   => {State::L, Instruction::NoBoundary, 60},
      {State::L, Property::V}   => {State::LVV, Instruction::NoBoundary, 60},
      {State::L, Property::LV}  => {State::LVV, Instruction::NoBoundary, 60},
      {State::L, Property::LVT} => {State::LVTT, Instruction::NoBoundary, 60},

      # GB7.
      {State::Any, Property::LV} => {State::LVV, Instruction::Boundary, 9990},
      {State::Any, Property::V}  => {State::LVV, Instruction::Boundary, 9990},
      {State::LVV, Property::V}  => {State::LVV, Instruction::NoBoundary, 70},
      {State::LVV, Property::T}  => {State::LVTT, Instruction::NoBoundary, 70},

      # GB8.
      {State::Any, Property::LVT} => {State::LVTT, Instruction::Boundary, 9990},
      {State::Any, Property::T}   => {State::LVTT, Instruction::Boundary, 9990},
      {State::LVTT, Property::T}  => {State::LVTT, Instruction::NoBoundary, 80},

      # GB9.
      {State::Any, Property::Extend} => {State::Any, Instruction::NoBoundary, 90},
      {State::Any, Property::ZWJ}    => {State::Any, Instruction::NoBoundary, 90},

      # GB9a.
      {State::Any, Property::SpacingMark} => {State::Any, Instruction::NoBoundary, 91},

      # GB9b.
      {State::Any, Property::Preprend} => {State::Prepend, Instruction::Boundary, 9990},
      {State::Prepend, Property::Any}  => {State::Any, Instruction::NoBoundary, 92},

      # GB11.
      {State::Any, Property::ExtendedPictographic}                     => {State::ExtendedPictographic, Instruction::Boundary, 9990},
      {State::ExtendedPictographic, Property::Extend}                  => {State::ExtendedPictographic, Instruction::NoBoundary, 110},
      {State::ExtendedPictographic, Property::ZWJ}                     => {State::ExtendedPictographicZWJ, Instruction::NoBoundary, 110},
      {State::ExtendedPictographicZWJ, Property::ExtendedPictographic} => {State::ExtendedPictographic, Instruction::NoBoundary, 110},

      # GB12 / GB13.
      {State::Any, Property::RegionalIndicator}    => {State::RIOdd, Instruction::Boundary, 9990},
      {State::RIOdd, Property::RegionalIndicator}  => {State::RIEven, Instruction::NoBoundary, 120},
      {State::RIEven, Property::RegionalIndicator} => {State::RIOdd, Instruction::Boundary, 120},
    } of Tuple(State, Property) => Tuple(State, Instruction, Int32)
  end
end
