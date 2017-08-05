#!/usr/bin/env ruby
require 'json'
$stdout.sync = true
$stderr.sync = true
$log = File.open("/tmp/a.log", "a")
$log.sync = true

def log(obj)
  str = format("[%5d] %s", Process.pid, (obj.is_a?(String) ? obj : obj.inspect))
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

log Time.now.to_s

send({me: "yarunee"})
read
res = read
case
when (id = res["punter"])
  my_state = {id: id}
  send({ready: id, state: my_state})
when res["move"]
  my_state = res["state"]
  send({move: {claim: {punter: my_state["id"],
                       source: 1,
                       target: 2}},
        state: my_state})
when res["stop"]
  log "Game over (score: #{res["stop"]["scores"]})"
else
  raise "unknown msg"
end
