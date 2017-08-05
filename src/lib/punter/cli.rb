require "json"

module Punter
  class Cli
    def output(hash)
      puts hash.to_json
    end

    def input
      JSON.parse(gets)
    end

    def run
      output({ me: "yarunee" })
      input # you: "yarunee"

      init_hash = input
      # punter: integer,
      # punters: integer,
      # map: {
      #   sites: [integer, ...],
      #   revers: [ { source: integer, target: integer }, ...],
      #   mines: [integer, ...]
      # }
      my_punter = init_hash["punter"]
      rivers = init_hash["map"]["rivers"]
      output({ ready: my_punter })

      loop do
        hash = input
        # move or stop: {
        #   moves: [
        #     { claim or pass: { punter: integer, source: integer, target: integer }}, ...
        #   ]
        # }
        unless hash["stop"].nil?
          puts hash["stop"]["scores"]
          break
        end
        river = rivers.sample
        river["punter"] = my_punter
        output({ claim: river })
      end
    end
  end
end
