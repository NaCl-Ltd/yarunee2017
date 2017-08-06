require 'json'
require 'sinatra'
require 'sinatra/reloader'

map_file = "#{__dir__}/../" +
  "data/play_logs/yhara/game_9009.jsons"

get '/' do
  initial_data, *game_progress, finish_data = File.readlines(map_file).map{|line| JSON.parse(line)}
  orig_map_data = initial_data["map"]

  # マップデータを読み込む
  nodes = []
  edges = Hash.new{|h, k| h[k] = {}}
  min_x = min_y = Float::INFINITY
  max_x = max_y = -Float::INFINITY
  mines = orig_map_data["mines"]
  orig_map_data["sites"].each do |site|
    x, y = site["x"], site["y"]
    min_x = x if x < min_x
    min_y = y if y < min_y
    max_x = x if x > max_x
    max_y = y if y > max_y
    nodes[site["id"]] = [x, y, mines.include?(site["id"])]
  end
  orig_map_data["rivers"].each do |river|
    s, t = river["source"], river["target"]
    edges[[s,t].min][[s,t].max] = -1
  end

  # スコアを読み込む
  scores = []
  finish_data["stop"]["scores"].each do |x| 
    scores[x["punter"]] = x["score"]
  end

  # ゲームの経過を反映
  game_progress.each do |turn|
    turn["move"]["moves"].each do |move|
      next unless move["claim"]  # passの場合はスキップ
      id, src, tgt = move["claim"].values_at("punter", "source", "target")
      edges[[src,tgt].min][[src,tgt].max] = id
    end
  end
  edges_ary = edges.sort.flat_map{|src, items|
    items.sort.map{|dst, owner|
      raise if src >= dst
      [src, dst, owner]
    }
  }

  # Opal側で使用するデータ
  mapData = {
    min_x: min_x,
    min_y: min_y,
    max_x: max_x,
    max_y: max_y,
    width: max_x - min_x,
    height: max_y - min_y,
    nodes: nodes,
    edges: edges_ary,
    mines: orig_map_data["mines"],
    player_id: initial_data["punter"],
    scores: scores,
  }

  <<-EOD
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset= "utf-8" />
        <title>パンター</title>
        <script type="text/javascript" src="dxopal.min.js"></script>
        <script type="text/ruby" src="main.rb"></script>
      </head>
      <body>
        <canvas id="canvas"></canvas>
        <script type="text/javascript">
          window.mapData = #{mapData.to_json};
        </script>
      </body>
    </html>
  EOD
end
