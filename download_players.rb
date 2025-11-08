require "json"
require "net/http"
require "pry"
require "csv"

=begin
curl 'https://www.fantrax.com/fxpa/req?leagueId=ypvvwpapmd8vkumr' \
  --compressed \
  -X POST \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:143.0) Gecko/20100101 Firefox/143.0' \
  -H 'Accept: application/json' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H 'Content-Type: text/plain' \
  -H 'Referer: https://www.fantrax.com/fantasy/league/ypvvwpapmd8vkumr/team/roster' \
  -H 'Origin: https://www.fantrax.com' \
  -H 'DNT: 1' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Connection: keep-alive' \
  -H 'Cookie: ... \
  --data-raw '{"msgs":[{"method":"getPlayerProfile","data":{"playerId":"06cmb","teamId":"w9lr7233me0m50tp"}},{"method":"getFantasyTeams","data":{}}],"uiv":3,"refUrl":"https://www.fantrax.com/fantasy/league/ypvvwpapmd8vkumr/team/roster","dt":0,"at":0,"av":"0.0","tz":"America/Denver","v":"172.1.0"}'
=end

class FantraxClient
  def initialize
    @base_uri = URI("https://www.fantrax.com")
    @league_id = ENV["FANTRAX_LEAGUE_ID"]
    @default_headers = {
      "Cookie" => ENV["FANTRAX_COOKIE"]
    }
  end

  def http
    http = Net::HTTP.new(@base_uri.host, @base_uri.port)
    http.use_ssl = true
    # uncomment to see request details
    #http.set_debug_output($stdout)
    http
  end

  def get(path:, headers: {})
    http.get(path, @default_headers.merge(headers))
  end

  def post(path:, body:, headers: {})
    http.post(path, body, @default_headers.merge(headers))
  end

  def get_players
    response = post(path: "/fxpa/downloadPlayerStats?leagueId=#{@league_id}&statusOrTeamFilter=ALL", body: "")
  end

  def get_players_as_csv
    response = get_players
    CSV.parse(response.body, headers: true)
  end

  def get_player_stats(player_id:)
    post(
      path: "/fxpa/req?leagueId=#{@league_id}",
      body: {
        "msgs" => [
          {
            "method" => "getPlayerProfile",
            "data" => {
              "playerId" => player_id,
              "tab" => "GAME_LOG_FANTASY"
            }
          },
          {
            "method" => "getFantasyTeams",
            "data" => {}
          }
        ]
      }.to_json
    )
  end

  # unused - non-fantasy data is not very useful
  def get_player_stats_as_json(player_id:)
    response = get_player_stats(player_id: player_id)
    json = JSON.parse(response.body)
    total_stats_headers = json["responses"][0]["data"]["sectionContent"]["OVERVIEW"]["tables"][0]["header"]["cells"]
    total_stats_rows    = json["responses"][0]["data"]["sectionContent"]["OVERVIEW"]["tables"][0]["rows"][0]["cells"]
    games_stats_headers = json["responses"][0]["data"]["sectionContent"]["OVERVIEW"]["tables"][1]["header"]["cells"]
    games_stats_rows    = json["responses"][0]["data"]["sectionContent"]["OVERVIEW"]["tables"][1]["rows"].map { |h| h["cells"] }
    # values
    total_stats_headers_values = total_stats_headers.map { |h| h["name"] }
    total_stats_rows_values    = total_stats_rows.map { |h| h["content"] }
    games_stats_headers_values = games_stats_headers.map { |h| h["name"] }
    games_stats_rows_values    = games_stats_rows.map { |row| row.map { |h| h["content"] } }
    {
      total: total_stats_headers_values.zip(total_stats_rows_values).to_h,
      games: games_stats_rows_values.map { |game_stats_rows_values| games_stats_headers_values.zip(game_stats_rows_values).to_h },
    }
  end

  # primary method to pull fantasy data per game for each player
  def get_player_games_as_json(player_id:)
    response = get_player_stats(player_id: player_id)
    json = JSON.parse(response.body)
    games_stats_headers = json["responses"][0]["data"]["sectionContent"]["GAME_LOG_FANTASY"]["tables"][0]["header"]["cells"]
    games_stats_rows    = json["responses"][0]["data"]["sectionContent"]["GAME_LOG_FANTASY"]["tables"][0]["rows"].map { |h| h["cells"] }
    # values
    games_stats_headers_values = games_stats_headers.map { |h| h["name"] }
    games_stats_rows_values    = games_stats_rows.map { |row| row.map { |h| h["content"] } }
    games_stats_rows_values.map { |game_stats_rows_values| games_stats_headers_values.zip(game_stats_rows_values).to_h }
  end

  # combine games for each player into a CSV
  def export_player_stats_for_games
    player_hashes = []
    base_headers = [
      "ID",
      "Player",
      "Team",
      "Position",
      "Owner",
      "Next Opponent",
      "TFPts",
      "TFP/G",
      "Rostered %",
      "+/- %"
    ]
    fantasy_headers = [
      "Date",
      "Opponent",
      "Score",
      "Fantasy Points",
      "Minutes Played",
      "Goals",
      "Assists (Official)",
      "Assists (Second)",
      "Key Passes (Assists on Shots)",
      "Assists (Fantasy)",
      "Shots on Target",
      "Shots off the Post",
      "Tackles Won",
      "Dispossessed",
      "Yellow Cards",
      "Red Cards",
      "Accurate Crosses",
      "Accurate Crosses (No Corners)",
      "Interceptions",
      "Interceptions + Blocked Shots",
      "Effective Clearances",
      "Successful Dribbles (Contests Succeeded)",
      "Blocked Crosses",
      "Blocked Shots",
      "Aerials Won",
      "Penalty Kicks Missed",
      "Penalty Kicks Drawn",
      "Own Goals",
      "Goals Against Outfielders ",
      "Clean Sheets On Field"
    ]
    csv_headers = base_headers + fantasy_headers

    # skip goalies as they have different stats
    players = get_players_as_csv.reject do |player_row|
      player_row["Position"] == "G"
    end
    i = 0
    players.each do |player_row|
      i += 1
      puts "#{i} / #{players.size} Players"

      player_hash = base_headers.zip([
        player_row["ID"].gsub("*", ""),
        player_row["Player"],
        player_row["Team"],
        player_row["Position"],
        # sometimes is a value like "W <small>(Wed)</small>"
        player_row["Status"].include?("<small>") ? "FA" : player_row["Status"],
        player_row["Opponent"],
        player_row["FPts"],
        player_row["FP/G"],
        player_row["Ros"],
        player_row["+/-"],
      ]).to_h
      2.times do
        begin
          # needed to prevent rate limit errors
          sleep 1.2
          get_player_games_as_json(player_id: player_hash["ID"]).each do |game|
            fantasy_headers |= game.keys
            game_player_hash = player_hash.merge(fantasy_headers.zip(game.values_at(*fantasy_headers)).to_h)
            game_player_hash["Opponent"].gsub!("@", "")
            player_hashes << game_player_hash
          end
          break
        rescue StandardError => error
          puts "#{error.class}: #{error.message}"
          puts error.backtrace
          puts player_hash
        end
      end
    end
    export_csv_s = CSV.generate(headers: true, force_quotes: true) do |export_csv|
      export_csv << csv_headers
      player_hashes.each { |player_hash| export_csv << player_hash.values_at(*csv_headers) }
    end
    File.open("players.csv", "w") { |f| f.write(export_csv_s) }
    player_hashes
  end

end

# actual call to client download data
client = FantraxClient.new
client.export_player_stats_for_games
