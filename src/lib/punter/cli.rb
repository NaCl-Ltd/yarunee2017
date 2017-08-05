require "json"

module Punter
  class Cli
    def log(str)
      @log ||= File.open("/tmp/aaa.log", "a")
      @log.puts str
    end

    def output(hash)
      hash["state"] = @state if @state
      json = hash.to_json
      log(json)
      print "#{json.length}:#{json}"
    end

    def input
      n = ""
      d = ""
      loop do
        c = STDIN.getc
        if c =~ /\d/
          n << c
        else
          n = n.to_i
          break
        end
      end
      n.times { d << STDIN.getc}
      log(d)
      r = JSON.parse(d)
      @state = r["state"] || {}
      r
    end

    def run
      output({ me: "yarunee" })
      input # you: "yarunee"

      hash = input
      case
      when hash["stop"]
      when hash["punter"]
        @state["punter"] = hash["punter"]
        @state["punters"] = hash["punters"]
        @state["sites"] = hash["map"]["sites"]
        @state["rivers"] = hash["map"]["rivers"]
        @state["mines"] = hash["map"]["mines"]
        output({ ready: @state["punter"] })
      when hash["move"]
        solve
      end
    end

    def solve
      river = @state["rivers"].sample
      river["punter"] = @state["punter"]
      output({ move: { claim: river }})
    end
  end
end
