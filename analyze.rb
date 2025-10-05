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
games_by_player = csv.map(&:to_hash).group_by { |h| h["Player"] }
results = {}
games_by_player.each do |player, hashes|
  puts hashes.first
  #next if !hashes.first || hashes.first["Owner"] != "FA"
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

trends.sort_by { |k,v| -v[:slope] }.each do |player, trend|
  puts "#{player.ljust(20)} - #{trend}"
end
