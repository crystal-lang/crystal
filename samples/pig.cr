# Translated from Go: http://golang.org/doc/codewalk/functions/

Win            = 100 # The winning score in a game of Pig
GamesPerSeries =  10 # The number of games per series to simulate

# A score includes scores accumulated in previous turns for each player,
# as well as the points scored by the current player in this turn.
record Score,
  player : Int32,
  opponent : Int32,
  this_turn : Int32

# roll returns the {result, turn_is_over} outcome of simulating a die roll.
# If the roll value is 1, then this_turn score is abandoned, and the players'
# roles swap.  Otherwise, the roll value is added to this_turn.
def roll(s)
  outcome = rand 1..6
  if outcome == 1
    {Score.new(s.opponent, s.player, 0), true}
  else
    {Score.new(s.player, s.opponent, outcome + s.this_turn), false}
  end
end

# stay returns the {result, turn_is_over} outcome of staying.
# this_turn score is added to the player's score, and the players' roles swap.
def stay(s)
  {Score.new(s.opponent, s.player + s.this_turn, 0), true}
end

# stay_at_k returns a strategy that rolls until this_turn is at least k, then stays.
def stay_at_k(k)
  ->(s : Score) do
    if s.this_turn >= k
      ->stay(Score)
    else
      ->roll(Score)
    end
  end
end

# play simulates a Pig game and returns the winner (0 or 1).
def play(strategy0, strategy1)
  strategies = {strategy0, strategy1}
  s = Score.new(0, 0, 0)
  turn_is_over = false
  current_player = rand(2)
  while s.player + s.this_turn < Win
    action = strategies[current_player].call(s)
    s, turn_is_over = action.call(s)
    if turn_is_over
      current_player = (current_player + 1) % 2
    end
  end
  current_player
end

# roundRobin simulates a series of games between every pair of strategies.
def round_robin(strategies)
  wins = Array.new(strategies.size, 0)
  (0...strategies.size).each do |i|
    (i + 1...strategies.size).each do |j|
      (0...GamesPerSeries).each do |k|
        winner = play strategies[i], strategies[j]
        if winner == 0
          wins[i] += 1
        else
          wins[j] += 1
        end
      end
    end
  end

  games_per_strategy = GamesPerSeries * (strategies.size - 1)
  {wins, games_per_strategy}
end

# ratio_string takes a list of integer values and returns a string that lists
# each value and its percentage of the sum of all values.
# e.g., ratios(1, 2, 3) = "1/6 (16.7%), 2/6 (33.3%), 3/6 (50.0%)"
def ratio_string(vals)
  total = vals.sum
  vals.map do |val|
    pct = ((100 * val.to_f / total.to_f) * 10).to_i / 10.0
    "#{val}/#{total} %#{pct}"
  end.join ", "
end

strategies = Array.new(Win) { |k| stay_at_k(k + 1) }
wins, games = round_robin strategies

strategies.each_with_index do |strategy, k|
  puts "Wins, losses staying at k = #{k + 1}: #{ratio_string({wins[k], games - wins[k]})}"
end
