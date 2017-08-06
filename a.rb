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

log Time.now.to_s

send({me: "yarunee"})
read
res = read
case
when (id = res["punter"])
  File.open($play_log, "a"){|f| f.puts res.to_json} if $play_log
  my_state = {id: id, n_punters: res["punters"], map: parse_map_data(res["map"]) }
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

  # まだ取られていない最初の川を選ぶ
  edges = map["edges"].flat_map{|src_key, hsh| hsh.map{|tgt_key, owner|
    [src_key.to_i, tgt_key.to_i, owner]
  }}
  src, tgt, _ = edges.find{|_, _, owner| owner == -1}

  send({claim: {punter: id,
                source: src,
                target: tgt},
        state: my_state})
when res["stop"]
  File.open($play_log, "a"){|f| f.puts res.to_json} if $play_log
  log "Game over (score: #{res["stop"]["scores"]})"
else
  raise "unknown msg"
end
