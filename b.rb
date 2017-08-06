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
  edges = Hash.new{|h, k| h[k] = {}}
  mines = map_data["mines"]

  map_data["rivers"].each do |river|
    s, t = river["source"], river["target"]
    edges[[s,t].min.to_s][[s,t].max.to_s] = -1
  end

  return {
    # 辺の一覧
    # 二重のハッシュになっている。キーは文字列(JSONの仕様のため)
    # キー1：両端のIDのうち小さい方
    # キー2：両端のIDのうち大きい方
    # 値：その川の持ち主(まだ誰も取っていないときは-1)
    # 例：{"1" => {"2" => -1}}  (1-2を繋ぐ川のみがあり、持ち主はなし)
    edges: edges,
    # 鉱脈の番号の一覧(例：[1,3])
    mines: mines
  }
end

# rivers: [[src, dst, owner], ...]
def next_river(rivers, mines, state)
  tips = state["tips"]
  free_rivers = rivers.select{|_, _, owner| owner == -1}

  # 鉱脈周りの川が空いていたらランダムで一本だけ抑える
  if tips.empty?
    src, tgt, _ = free_rivers.select{|s, t, _|
      if mines.include?(s) && mines.include?(t)
        false
      elsif mines.include?(s)
        true
      elsif mines.include?(t)
        true
      else
        false
      end
    }.sample(1).first

    if mines.include?(src)
      state["tips"] << [tgt, 1]
    elsif mines.include?(tgt)
      state["tips"] << [src, 1]
    end
    return src, tgt, state if src
  end

  # 枝をひたすら先に伸ばす
  while tip = state["tips"].pop
    node, len = tip
    free_rivers.each do |s, t, _|
      if s == node || t == node
        state["tips"] << tip
        state["tips"] << [(s == node ? t : s), len+1]
        state["tips"].sort_by!{|node, len| len}
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
  my_state = {
    id: id,
    n_punters: res["punters"],
    map: parse_map_data(res["map"]),
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
    claimer_id, src, tgt = move["claim"].values_at("punter", "source", "target")
    map["edges"][[src,tgt].min.to_s][[src,tgt].max.to_s] = claimer_id
  end

  # 川の一覧を作る
  edges = map["edges"].flat_map{|src_key, hsh| hsh.map{|tgt_key, owner|
    [src_key.to_i, tgt_key.to_i, owner]
  }}

  src, tgt, new_state = next_river(edges, map["mines"], my_state)

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
