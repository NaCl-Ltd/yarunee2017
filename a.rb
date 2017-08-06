#!/usr/bin/env ruby
require 'json'
$stdout.sync = true
$stderr.sync = true
$log = File.open("/tmp/a.log", "a")
$log.sync = true
$play_log = ENV["PLAY_LOG"]

MAX_LOG_LEN = 200
def log(obj)
  str = format("[%5d] %s", Process.pid, (obj.is_a?(String) ? obj : obj.inspect))
  if str.length > MAX_LOG_LEN
    str = str[0, MAX_LOG_LEN] + "..."
  end
  $log.puts str
  $stderr.puts str
end

def send(json_data)
  s = json_data.to_json
  msg = "#{s.bytesize}:#{s}"
  $stdout.print msg
  log sent: msg
end

def read
  len_s = ""
  len = nil
  json_s = ""
  loop do
    c = $stdin.getc
    if c =~ /\d/
      len_s << c
    else
      # cは':'なので捨てる
      len = len_s.to_i
      break
    end
  end
  len.times{ json_s << $stdin.getc }
  log received: json_s
  return JSON.parse(json_s)
end

# map jsonを扱いやすい形式に変換する
def parse_map_data(map_data)
  nodes = map_data["sites"].map{|x| x["id"]}.sort
  edges = Hash.new{|h, k| h[k] = {}}
  mines = map_data["mines"]

  map_data["rivers"].each do |river|
    s, t = river["source"].to_s, river["target"].to_s
    edges[s][t] = -1
    edges[t][s] = -1
  end

  return {
    # ノード番号の一覧
    # (0からの連番のように見えるが、保証されてないと思うので念のため、、)
    "nodes" => nodes,
    # 辺の一覧
    # 二重のハッシュになっている。キーは文字列(JSONの仕様のため)
    # キー1、キー2：両端のID
    # 値：その川の持ち主(まだ誰も取っていないときは-1)
    # 例：{"1" => {"2" => -1}  (1-2を繋ぐ川で、持ち主はなし)
    "edges" => edges,
    # 鉱脈の番号の一覧(例：[1,3])
    "mines" => mines
  }
end

# rootからの距離の一覧を作る
# return: [距離の一覧(map_data["nodes"]に対応)] 
def calc_dists(map_data, root_id)
  nodes = map_data["nodes"]
  node_idx = nodes.map.with_index{|node, i| [node, i]}.to_h
  visited = Array.new(nodes.length)
  edges = map_data["edges"]
  dists = Array.new(nodes.length)
  dists[node_idx[root_id]] = 0

  q = [root_id]
  until q.empty?
    from = q.shift
    visited[node_idx[from]] = true
    edges[from].each do |to, _|
      next if visited[node_idx[to]]
      dists[node_idx[to]] = dists[node_idx[from]] + 1
      q.push(to)
    end
  end

  return dists
end

# rivers: [[src, dst, owner], ...]
def next_river(rivers, mines, state)
  tips = state["tips"]
  free_rivers = rivers.select{|_, _, owner| owner == -1}

  # 鉱脈周りの川が空いていたらとりあえず押さえる
  src, tgt, _ = free_rivers.find{|s, t, _|
    if mines.include?(s) && mines.include?(t)
      true
    elsif mines.include?(s)
      state["tips"] << [t, 1]
      true
    elsif mines.include?(t)
      state["tips"] << [s, 1]
      true
    else
      false
    end
  }
  state["tips"].sort_by!{|node, len| -len}
  return src, tgt, state if src

  # そうでない場合、枝を伸ばしたい
  state["tips"].each.with_index do |(node, len), idx|
    free_rivers.each do |s, t, _|
      if s == node || t == node
        state["tips"][idx] = [(s == node ? t : s), len+1]
        state["tips"].sort_by!{|node, len| -len}
        return s, t, state
      end
    end
  end

  # 無理なら適当に
  src, tgt, _ = free_rivers.first
  return src, tgt, state
end

log "#{Time.now.to_s} #{$play_log}"

send({me: "yarunee"})
read
res = read
case
when (id = res["punter"])
  File.open($play_log, "a"){|f| f.puts res.to_json} if $play_log
  map_data = parse_map_data(res["map"])

  # 前処理
  mine_dists = {}
  map_data["mines"].each do |mine_id|
    mine_dists[mine_id] = calc_dists(map_data, mine_id)
  end

  my_state = {
    id: id,
    n_punters: res["punters"],
    map: map_data,
    # 各mineから各点までの距離の一覧
    # {mine_id => [各点までの距離(map["nodes"]に対応)]}
    mine_dists: mine_dists,
    tips: [],
  }
  send({ready: id, state: my_state})
when res["move"]
  my_state = res["state"]
  id = my_state["id"]
  File.open($play_log, "a"){|f| f.puts res.to_json} if $play_log
  map = my_state["map"]

  # 敵の挙動をmapに反映させる
  res["move"]["moves"].each do |move|
    next unless move["claim"]  # passの場合はスキップ
    claimer_id = move["claim"]["punter"]
    src = move["claim"]["source"].to_s
    tgt = move["claim"]["target"].to_s
    map["edges"][src][tgt] = claimer_id
    map["edges"][tgt][src] = claimer_id
  end

  # 川の一覧を作る
  edge_list = map["edges"].flat_map{|src_key, hsh| hsh.map{|tgt_key, owner|
    src, tgt = src_key.to_i, tgt_key.to_i
    [src, tgt, owner] if src < tgt
  }.compact}

  src, tgt, new_state = next_river(edge_list, map["mines"], my_state)

  send({claim: {punter: id,
                source: src,
                target: tgt},
        state: new_state})
when res["stop"]
  File.open($play_log, "a"){|f| f.puts res.to_json} if $play_log
  log "Game over (score: #{res["stop"]["scores"]})"
else
  raise "unknown msg"
end
