#!/usr/bin/env ruby
require 'json'

File.open("/tmp/a.log", "a") do |f|
  f.puts Time.now.to_s
end

def send(json_data)
  s = json_data.to_json
  puts "#{s.length}:#{s}"
end

send({me:"yarunee"})
#$stderr.puts $stdin.read.inspect
#send({ready:0})
