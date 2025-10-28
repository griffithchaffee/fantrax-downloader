require 'csv'
require 'pry'

class Array

  # stolen from stackoverflow - no idea how true it is but seems accurate
  def trend_line
    points = map.with_index { |y, x| [x+1, y] }
    n = points.size
    summation_xy = points.map{ |e| e[0]*e[1] }.inject(&:+)
    summation_x = points.map{ |e| e[0] }.inject(&:+)
    summation_y = points.map{ |e| e[1] }.inject(&:+)
    summation_x2 = points.map{ |e| e[0]**2 }.inject(&:+)
    slope = ( n * summation_xy - summation_x * summation_y ) / ( n * summation_x2 - summation_x**2 ).to_f
    offset = ( summation_y - slope * summation_x ) / n.to_f
    {slope: slope, offset: offset}
  end

end

csv = CSV.parse(File.read("players.csv"), headers: true)
players = csv.map(&:to_hash)
games_by_player = csv.map(&:to_hash).group_by { |h| h["Player"] }
games_by_player.select! do |player, hashes|
  next if hashes.size == 0
  hash = hashes.first
  # Ben White, Matt O'Riley
  next if %w[ 04qfq 04e1e ].include?(hash["ID"])
  next if hashes.sum { |h| h["Minutes Played"].to_f } <= 300
  #next if hash["Owner"] != "FA"
  true
end


next_games = {}
games_by_player.each do |player, hashes|
  hashes.each do |hash|
    next_games[hash["Team"]] ||= hash["Next Opponent"]
  end
end


puts
puts "========= TRENDING UP ========="
results = {}
games_by_player.each do |player, hashes|
  next if !hashes.first || hashes.first["Owner"] != "FA"
  hashes.each do |hash|
    next if hash["Minutes Played"].to_i <= 30
    results[player] ||= []
    results[player] << hash["Fantasy Points"].to_f
  end
end

trends = {}
results.each do |player, fpts|
  next if fpts.size <= 2
  trends[player] = fpts.trend_line
end
trends.sort_by { |k,v| -v[:slope] }.last(40).each do |player, trend|
  puts "#{player.ljust(20)} - #{trend[:slope].round(1) * -1}"
end


puts
puts "========= Defensive Points ========="
results.clear
games_by_player.each do |player, hashes|
  hashes.each do |hash|
    next if !["D", "D,M"].include?(hash["Position"])
    results[hash["Opponent"]] ||= 0
    results[hash["Opponent"]] += hash["Fantasy Points"].to_f
  end
end

results.sort_by { |k,v| -v }.each do |k,v|
  puts "#{k}: #{v.round} (#{next_games[k]})"
end


puts
puts "========= Mid Points ========="
results.clear
games_by_player.each do |player, hashes|
  hashes.each do |hash|
    next if !["M", "M,F", "D,M"].include?(hash["Position"])
    results[hash["Opponent"]] ||= 0
    results[hash["Opponent"]] += hash["Fantasy Points"].to_f
  end
end

results.sort_by { |k,v| -v }.each do |k,v|
  puts "#{k}: #{v.round} (#{next_games[k]})"
end


puts
puts "========= Forward Points ========="
results.clear
games_by_player.each do |player, hashes|
  hashes.each do |hash|
    next if !["F", "M,F"].include?(hash["Position"])
    results[hash["Opponent"]] ||= 0
    results[hash["Opponent"]] += hash["Fantasy Points"].to_f
  end
end

results.sort_by { |k,v| -v }.each do |k,v|
  puts "#{k}: #{v.round} (#{next_games[k]})"
end

puts
puts "========= No G/A Fpts ========="
results.clear
games_by_player.each do |player, hashes|
  fpts = 0.0
  mins = 0.0
  name = [player.ljust(30, " ")]
  hashes.each do |hash|
    name.unshift(hash["Position"].ljust(3, " ")) if name.size < 4
    name.unshift(hash["Team"]) if name.size < 4
    name.unshift(hash["Owner"].ljust(15, " ")) if name.size < 4
    next if ["D", "D,M"].include?(hash["Position"])
    fpts += hash["Fantasy Points"].to_f
    fpts -= 10 * hash["Goals"].to_f
    fpts -= 7 * hash["Assists (Official)"].to_f
    fpts -= 7 * hash["Assists (Fantasy)"].to_f
    mins += hash["Minutes Played"].to_f
  end
  next if mins <= 400
  results[name.join(" - ")] = fpts / mins
end

results.sort_by { |k,v| -v }.select { |k,v| k =~ /FA/ }.first(10).each do |k,v|
  puts "#{k}: #{v}"
end

puts
puts "========= Ftps / Mins No Outliers ========="
results.clear
games_by_player.each do |player, hashes|
  fpts = []
  mins = 0.0
  name = [player.ljust(30, " ")]
  hashes.each do |hash|
    name.unshift(hash["Position"].ljust(3, " ")) if name.size < 4
    name.unshift(hash["Team"]) if name.size < 4
    name.unshift(hash["Owner"].ljust(15, " ")) if name.size < 4
    fpts.push(hash["Fantasy Points"].to_f)
    mins += hash["Minutes Played"].to_f
  end
  next if mins <= 400
  fpts.delete(fpts.max)
  fpts.delete(fpts.min)
  fpts = fpts.sum
  next if fpts <= 0
  results[name.join(" - ")] = fpts / mins
end

results.sort_by { |k,v| -v }.select { |k,v| k =~ /FA/ }.first(10).each do |k,v|
  puts "#{k}: #{v}"
end
