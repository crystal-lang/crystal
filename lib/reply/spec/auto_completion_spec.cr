require "./spec_helper"

RESULTS = {
  "Int32", [
    "abs", "abs2", "bit", "bit_length", "bits", "bits_set?", "ceil", "chr",
    "clamp", "class", "clone", "crystal_type_id", "day", "days", "digits", "divisible_by?",
    "divmod", "downto", "dup", "even?", "fdiv", "floor", "format", "gcd",
    "hash", "hour", "hours", "humanize", "humanize_bytes", "in?", "inspect", "itself",
    "lcm", "leading_zeros_count", "microsecond", "microseconds", "millisecond", "milliseconds", "minute", "minutes",
    "modulo", "month", "months", "nanosecond", "nanoseconds", "negative?", "not_nil!", "odd?",
    "popcount", "positive?", "pred", "pretty_inspect", "pretty_print", "remainder", "round", "round_away",
    "round_even", "second", "seconds", "sign", "significant", "step", "succ", "tap",
    "tdiv", "times", "to", "to_f", "to_f!", "to_f32", "to_f32!", "to_f64",
    "to_f64!", "to_i", "to_i!", "to_i128", "to_i128!", "to_i16", "to_i16!", "to_i32",
    "to_i32!", "to_i64", "to_i64!", "to_i8", "to_i8!", "to_io", "to_s", "to_u",
    "to_u!", "to_u128", "to_u128!", "to_u16", "to_u16!", "to_u32", "to_u32!", "to_u64",
    "to_u64!", "to_u8", "to_u8!", "trailing_zeros_count", "trunc", "try", "unsafe_as", "unsafe_chr",
    "unsafe_div", "unsafe_mod", "unsafe_shl", "unsafe_shr", "upto", "week", "weeks", "year",
    "years", "zero?", "as", "as?", "is_a?", "nil?", "responds_to?",
  ],
}

module Reply
  describe AutoCompletion do
    describe "displays entries" do
      it "for many entries" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "abs         bits       clamp            \n" \
                   "abs2        bits_set?  class            \n" \
                   "bit         ceil       clone            \n" \
                   "bit_length  chr        crystal_type_id..\n",
          height: 5
      end

      it "for many entries with larger screen" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        handler.verify_display max_height: 5,
          with_width: 54,
          display: "Int32:\n" \
                   "abs         bits       clamp            \n" \
                   "abs2        bits_set?  class            \n" \
                   "bit         ceil       clone            \n" \
                   "bit_length  chr        crystal_type_id..\n",
          height: 5
        handler.verify_display max_height: 5,
          with_width: 55,
          display: "Int32:\n" \
                   "abs         bits       clamp            day            \n" \
                   "abs2        bits_set?  class            days           \n" \
                   "bit         ceil       clone            digits         \n" \
                   "bit_length  chr        crystal_type_id  divisible_by?..\n",
          height: 5
      end

      it "for many entries with higher screen" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "abs         bits       clamp            \n" \
                   "abs2        bits_set?  class            \n" \
                   "bit         ceil       clone            \n" \
                   "bit_length  chr        crystal_type_id..\n",
          height: 5
        handler.verify_display max_height: 6,
          with_width: 40,
          display: "Int32:\n" \
                   "abs         bits_set?  clone            \n" \
                   "abs2        ceil       crystal_type_id  \n" \
                   "bit         chr        day              \n" \
                   "bit_length  clamp      days             \n" \
                   "bits        class      digits..         \n",
          height: 6
      end

      it "for few entries" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("ab", "42.")
        handler.open
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "abs   \n" \
                   "abs2  \n",
          height: 3
      end

      it "when closed" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.close
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "",
          height: 0
      end

      it "when cleared" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.clear
        handler.verify_display max_height: 5, min_height: 3,
          with_width: 40,
          display: "\n\n\n",
          height: 3
        handler.verify_display max_height: 5, min_height: 5,
          with_width: 40,
          display: "\n\n\n\n\n",
          height: 5
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "",
          height: 0
      end

      it "when max height is zero" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        handler.verify_display max_height: 0,
          with_width: 40,
          display: "",
          height: 0
      end

      it "for no entry" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("___nop___", "42.")
        handler.open
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n",
          height: 1
      end
    end

    describe "moves selection" do
      it "selection next" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   "abs   bit_length  \n" \
                   "abs2  bits        \n" \
                   "bit   bits_set?.. \n",
          height: 4

        handler.selection_next
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   ">abs  bit_length  \n" \
                   "abs2  bits        \n" \
                   "bit   bits_set?.. \n",
          height: 4

        3.times { handler.selection_next }
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   "abs   >bit_length \n" \
                   "abs2  bits        \n" \
                   "bit   bits_set?.. \n",
          height: 4
      end

      it "selection next on next column" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        6.times { handler.selection_next }
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   "abs   bit_length  \n" \
                   "abs2  bits        \n" \
                   "bit   >bits_set?..\n",
          height: 4

        handler.selection_next
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   "bit_length  >ceil  \n" \
                   "bits        chr    \n" \
                   "bits_set?   clamp..\n",
          height: 4
      end

      it "selection previous" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        2.times { handler.selection_next }
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   "abs   bit_length  \n" \
                   ">abs2 bits        \n" \
                   "bit   bits_set?.. \n",
          height: 4

        handler.selection_previous
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   ">abs  bit_length  \n" \
                   "abs2  bits        \n" \
                   "bit   bits_set?.. \n",
          height: 4

        handler.selection_previous
        handler.verify_display max_height: 4,
          with_width: 20,
          display: "Int32:\n" \
                   "nil?          \n" \
                   ">responds_to? \n" \
                   "\n",
          height: 4
      end
    end

    describe "name filter" do
      it "changes" do
        handler = SpecHelper.auto_completion(returning: RESULTS)
        handler.complete_on("", "42.")
        handler.open
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "abs         bits       clamp            \n" \
                   "abs2        bits_set?  class            \n" \
                   "bit         ceil       clone            \n" \
                   "bit_length  chr        crystal_type_id..\n",
          height: 5
        handler.name_filter = "to"

        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "to      to_f32!  to_i!     to_i16!  \n" \
                   "to_f    to_f64   to_i128   to_i32   \n" \
                   "to_f!   to_f64!  to_i128!  to_i32!  \n" \
                   "to_f32  to_i     to_i16    to_i64.. \n",
          height: 5

        handler.name_filter = "to_nop"
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n",
          height: 1

        handler.name_filter = "to_"
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "to_f     to_f64   to_i128   to_i32   \n" \
                   "to_f!    to_f64!  to_i128!  to_i32!  \n" \
                   "to_f32   to_i     to_i16    to_i64   \n" \
                   "to_f32!  to_i!    to_i16!   to_i64!..\n",
          height: 5

        handler.name_filter = "to_i32!"
        handler.verify_display max_height: 5,
          with_width: 40,
          display: "Int32:\n" \
                   "to_i32!  \n",
          height: 2
      end
    end
  end
end
