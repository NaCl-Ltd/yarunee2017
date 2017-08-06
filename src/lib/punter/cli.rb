require "json"

module Punter
  class Cli
    def log(str)
      @log ||= File.open("/tmp/aaa.log", "a")
      @log.sync = true
      @log.puts str
    end

    def output(hash)
      hash["state"] = @state if @state
      json = hash.to_json
      out = "#{json.length}:#{json}"
      log(out)
      print out
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
        @state["rivers"] = {}
        hash["map"]["rivers"].each do |river|
          @state["rivers"][river["source"].to_s] ||= []
          @state["rivers"][river["source"].to_s] << river["target"]
          @state["rivers"][river["target"].to_s] ||= []
          @state["rivers"][river["target"].to_s] << river["source"]
        end
        @state["mines"] = hash["map"]["mines"]
        output({ ready: @state["punter"] })
      when hash["move"]
        hash["move"]["moves"].each do |move|
          if move["claim"]
            m = move["claim"]
            @state["rivers"][m["source"].to_s].delete(m["target"])
            @state["rivers"].delete(m["source"].to_s) if @state["rivers"][m["source"].to_s].empty?
            @state["rivers"][m["target"].to_s].delete(m["source"])
            @state["rivers"].delete(m["target"].to_s) if @state["rivers"][m["target"].to_s].empty?
          end
        end
        solve
      end
    end

    def solve
      r = @state["rivers"].to_a.sample
      river = {
        source: r[0].to_i, target: r[1].sample, punter: @state["punter"]
      }
      output({ claim: river })
    end
  end
end
