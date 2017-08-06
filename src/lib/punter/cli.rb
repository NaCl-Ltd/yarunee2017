require "json"

module Punter
  class Cli
    def initialize
      @log = File.open("/tmp/aaa.log", "a")
      @log.sync = true
    end

    def log(str)
      @log.puts str
    end

    def visual_log(hash)
      @visual_log ||= File.open("/tmp/visual.log", "a")
      @visual_log.sync = true
      @visual_log.puts hash.to_json
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
      log(n.to_s + ":" + d)
      r = JSON.parse(d)
      @state = r["state"] || {}
      r
    end

    def run
      output({ me: "yarunee" })
      input # you: "yarunee"

      hash = input
      visual_log(hash)
      case
      when hash["stop"]
      when hash["punter"]
        @state["punter"] = hash["punter"]
        @state["punters"] = hash["punters"]
        @state["sites"] = hash["map"]["sites"].map { |i| i["id"] }
        @state["rivers"] = {}
        hash["map"]["rivers"].each do |river|
          @state["rivers"][river["source"].to_s] ||= []
          @state["rivers"][river["source"].to_s] << river["target"]
          @state["rivers"][river["target"].to_s] ||= []
          @state["rivers"][river["target"].to_s] << river["source"]
        end
        @state["mines"] = hash["map"]["mines"]
        @state["my_sites"] = @state["mines"]
        calc_site_distance
        @state["sites_distances"] = @sites
        @state["mine_routes"] = @state["mines"].map { |i| [i, [i]] }.to_h
        @state["connect"] = true
        output({ ready: @state["punter"] })
      when hash["move"]
        hash["move"]["moves"].each do |move|
          if move["claim"]
            m = move["claim"]
            @state["rivers"][m["source"].to_s].delete(m["target"])
            @state["rivers"].delete(m["source"].to_s) if @state["rivers"][m["source"].to_s].empty?
            @state["rivers"][m["target"].to_s].delete(m["source"])
            @state["rivers"].delete(m["target"].to_s) if @state["rivers"][m["target"].to_s].empty?
            if m["punter"] == @state["punter"]
              %w(source target).each do |label|
                @state["my_sites"].unshift m[label] unless @state["my_sites"].include?(m[label])
              end
              if (f = fetch_site_to_mine(m["source"])).nil?
                f = fetch_site_to_mine(m["target"])
                new_site = m["source"]
              else
                new_site = m["target"]
              end
              @state["mine_routes"][f.to_s] << new_site
              if @state["mines"].include?(new_site)
                @state["connect"] = false
              end
            end
          end
        end
        solve
      end
    end

    def solve
      source = nil
      target = nil
      @state["my_sites"].each do |site|
        targets = @state["rivers"][site.to_s]
        if targets && !targets.empty?
          source = site
          mine = fetch_site_to_mine(site)
          if @state["connect"]
            target = targets.min_by do |i|
              @state["sites_distances"].select do |k,v|
                k.to_s != mine.to_s
              end.map do |k,v|
                v[i.to_s]
              end.flatten.min
            end
          else
            target = targets.max_by do |i|
              @state["sites_distances"].map do |k,v|
                v[i.to_s]
              end.flatten.min
            end
          end
          break
        end
      end
      if source
        river = {
          source: source, target: target, punter: @state["punter"]
        }
        output({ claim: river })
      else
        pass = { pass: { punter: @state["punter"]}}
        output(pass)
      end
    end

    # 各mineごとに各siteへの距離を計算する
    def calc_site_distance
      @sites = {}
      @state["mines"].each do |mine|
        sites = {}
        @state["sites"].each do |site|
          sites[site] = 99999999
        end
        sites[mine] = 0
        q = [[mine, 0]]
        q.each do |site, d|
          targets = @state["rivers"][site.to_s]
          if targets
            targets.each do |target|
              if sites[target] > d + 1
                sites[target] = d + 1
                q << [target, d + 1]
              end
            end
          end
        end
        @sites[mine] = sites
      end
    end

    # site id からどのmine(id)由来の道か返す
    def fetch_site_to_mine(site)
      @state["mine_routes"].select { |k,v| v.include?(site) }.keys.first&.to_i
    end
  end
end
