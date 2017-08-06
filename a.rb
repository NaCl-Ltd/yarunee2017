#!/usr/bin/env ruby
require 'json'
$stdout.sync = true
$stderr.sync = true
$log = File.open("/tmp/a.log", "a")
$log.sync = true
$play_log = ENV["PLAY_LOG"]

MAX_LOG_LEN = 200
def log(obj, no_cut: false)
  str = format("[%5d] %s", Process.pid, (obj.is_a?(String) ? obj : obj.inspect))
  if str.length > MAX_LOG_LEN && !no_cut
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
def calc_dists(nodes, edges, root_id)
  node_idx = nodes.map.with_index{|node, i| [node, i]}.to_h
  visited = Array.new(nodes.length)
  # TODO: 盤面が連結でないケースはあるか？
  dists = Array.new(nodes.length, -1)
  dists[node_idx[root_id]] = 0

  q = [root_id]
  until q.empty?
    from = q.shift
    visited[node_idx[from]] = true
    edges[from.to_s].each do |key, _|
      to = key.to_i
      next if visited[node_idx[to]]
      dists[node_idx[to]] = dists[node_idx[from]] + 1
      q.push(to)
    end
  end

  return dists
end

def next_river(nodes, edges, mines, state)
  mine_dists = state["mine_dists"]
  # 鉱脈周りの川を一本ずつ押さえる
  mines.each do |mine|
    mine_key = mine.to_s
    next if state["domain"].key?(mine_key)

    edges[mine_key].each do |dst_key, owner|
      dst = dst_key.to_i
      if owner == -1
        state["domain"][mine_key] = [dst]
        return mine, dst, state
      end
    end
  end

  # 枝を伸ばす
  candidates = state["domain"].flat_map{|mine_key, nodes|
    mine = mine_key.to_i
    nodes.flat_map{|node|
      edges[node.to_s].flat_map{|dst_key, owner|
        dst = dst_key.to_i
        if owner == -1
          score = mine_dists[mine_key][nodes.index(node)]
          [[score, mine_key, node, dst]]
        else
          []
        end
      }
    }
  }
  score, mine_key, node, dst = candidates.max_by{|x| x[0]}
  if score
    state["domain"][mine_key] << dst
    return node, dst, state
  end
    # TODO: domain併合処理

  # 無理なら適当に
  edges.each do |key1, hsh|
    hsh.each do |key2, owner|
      return key1.to_i, key2.to_i, state if owner == -1
    end
  end
  raise
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
    mine_dists[mine_id] = calc_dists(map_data["nodes"], map_data["edges"], mine_id)
  end
  # 伸びしろでソート
  map_data["mines"].sort_by!{|mine_id| -mine_dists[mine_id].max}

  my_state = {
    id: id,
    n_punters: res["punters"],
    map: map_data,
    # 各mineから各点までの距離の一覧
    # {mine_id => [各点までの距離(map["nodes"]に対応)]}
    mine_dists: mine_dists,
    # 領地
    # {mines: [mine_id, ...], nodes: [node_id, ...]}
    domain: {},
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

  src, tgt, new_state = next_river(map["nodes"], map["edges"], map["mines"], my_state)

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
