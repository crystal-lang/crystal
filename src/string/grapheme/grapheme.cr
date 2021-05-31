require "./properties"

module String::Grapheme
  # Grapheme Cluster correspond to
  # "user-perceived characters". These characters often consist of multiple
  # code points (e.g. the "woman kissing woman" emoji consists of 8 code points:
  # woman + ZWJ + heavy black heart (2 code points) + ZWJ + kiss mark + ZWJ +
  # woman) and the rules described in Annex #29 must be applied to group those
  # code points into clusters perceived by the user as one character.
  struct Cluster
    @cluster : Array(Tuple(Char, Int32))

    protected def initialize(@cluster)
    end

    def pos
      @cluster.size > 0 ? @cluster[0][1] : -1
    end

    def to_s(io : IO) : Nil
      io << (@cluster.size > 1 ? @cluster.map(&.[0]).join : @cluster[0][0])
    end
  end

  # Graphemes implements an iterator over Unicode extended grapheme clusters,
  # specified in the Unicode Standard Annex #29.
  class Graphemes
    include Iterator(Cluster)

    @last_char : Char? = nil

    def initialize(str : String)
      @reader = Char::Reader.new(str)
      @state = State::Any
      @cluster = [] of Tuple(Char, Int32)
      @look_ahead = true
      @last_char_pos = 0
      move_next # Parse ahead
    end

    def next
      move_next
      return stop if @cluster.empty?
      val = Cluster.new(@cluster.dup)
      @cluster.clear
      val
    end

    # advances the iterator by one grapheme cluster
    # This method must be called before the first cluster is accessed
    private def move_next
      if (c = @last_char) && @cluster.empty?
        @cluster << {c, @last_char_pos}
        @last_char = nil
      end

      while @reader.has_next?
        value = @reader.current_char
        @cluster << {value, @reader.pos}
        @reader.next_char

        next_prop = Property.from(value.ord)

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
        if @look_ahead || boundary
          unless @cluster.size == 1
            @last_char, @last_char_pos = @cluster.delete_at(-1)
          end
          @look_ahead = false
          break
        end
      end
    end

    # cluster parser states
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

    # cluster parser's breaking instructions.
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
    @transitions : Hash(Tuple(State, Property), Tuple(State, Instruction, Int32)) = {
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
      {State::Any, Property::Prepend} => {State::Prepend, Instruction::Boundary, 9990},
      {State::Prepend, Property::Any} => {State::Any, Instruction::NoBoundary, 92},

      # GB11.
      {State::Any, Property::ExtendedPictographic}                     => {State::ExtendedPictographic, Instruction::Boundary, 9990},
      {State::ExtendedPictographic, Property::Extend}                  => {State::ExtendedPictographic, Instruction::NoBoundary, 110},
      {State::ExtendedPictographic, Property::ZWJ}                     => {State::ExtendedPictographicZWJ, Instruction::NoBoundary, 110},
      {State::ExtendedPictographicZWJ, Property::ExtendedPictographic} => {State::ExtendedPictographic, Instruction::NoBoundary, 110},

      # GB12 / GB13.
      {State::Any, Property::RegionalIndicator}    => {State::RIOdd, Instruction::Boundary, 9990},
      {State::RIOdd, Property::RegionalIndicator}  => {State::RIEven, Instruction::NoBoundary, 120},
      {State::RIEven, Property::RegionalIndicator} => {State::RIOdd, Instruction::Boundary, 120},
    }
  end
end
