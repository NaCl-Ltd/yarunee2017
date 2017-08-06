#!/usr/bin/env ruby

require "open-uri"
require "open3"
require "pathname"
require "pp"
require "tempfile"

require "mechanize"
require "slack-ruby-client"

TOP_SRC_PATH = Pathname(__dir__).parent.expand_path
STATUS_URI = URI("http://punter.inf.ed.ac.uk/status.html")
LAMDUCT_VERSION = "0.3"
LAMDUCT_URI = URI("https://raw.githubusercontent.com/icfpcontest2017/icfpcontest2017.github.io/master/static/lamduct-#{LAMDUCT_VERSION}")
LAMDUCT_PATH = TOP_SRC_PATH / "vendor/downloads/lamduct-#{LAMDUCT_VERSION}"
VISUAL_LOG_PATH = Pathname("/tmp/visual.log")
POST_CHANNEL = "atcoder"

def run(*args)
  p([:running, Dir.pwd, *args])
  if !system(*args)
    raise "failure: #{args.inspect}"
  end
end

# lamductのインストール
if !LAMDUCT_PATH.executable?
  Tempfile.open do |f|
    f.write(LAMDUCT_URI.read)
    f.close
    File.chmod(0755, f.path)
    LAMDUCT_PATH.parent.mkpath
    FileUtils.mv(f.path, LAMDUCT_PATH)
  end
end

# Slackクライアント初期化
Slack.configure do |c|
  c.token = ENV["SLACK_API_TOKEN"]
end
slack_client = Slack::Web::Client.new
slack_client.auth_test

# 接続先を決定
game_boards = []
agent = Mechanize.new
page = agent.get(STATUS_URI)
page.css("tr")[1 .. -1].each do |tr|
  status = tr.css("td")[0].content
  md = %r|Waiting for punters\. \((\d+)/(\d+)\)|.match(status)
  p([:detect, md, status])
  if !md
    next
  end
  current_n_panters = md[1].to_i
  required_n_panters = md[2].to_i
  if current_n_panters + 1 == required_n_panters
    tds = tr.css("td")
    game_boards << {
      punters: tds[1].content,
      extensions: tds[2].content,
      port: tds[4].content.to_i,
      map_name: tds[5].content,
    }
  end
end
pp(game_boards: game_boards)

# lamductを実行
build_uri = [
  ENV["CI_PROJECT_URL"], "builds", ENV["CI_JOB_ID"],
].join("/")
Dir.chdir(TOP_SRC_PATH.to_s) do
  game_boards.shuffle[0, 5].each do |game_board|
    command = [
      LAMDUCT_PATH.to_s,
      "--game-port=#{game_board[:port]}", "--log-level=3",
      "./punter",
    ]
    p([:running, Dir.pwd, *command])
    if !Bundler.clean_system(*command) # 失敗時
      slack_client.chat_postMessage(channel: POST_CHANNEL,
                                    text: "#{build_uri}: failure: #{command.join(' ')}")
      next
    end
    # 成功時
    comment = {
      uri: build_uri,
      game_port: game_board[:port],
      map_name: game_board[:map_name],
      punters: game_board[:punters],
      CI_COMMIT_REF_NAME: ENV["CI_COMMIT_REF_NAME"],
      CI_COMMIT_SHA: ENV["CI_COMMIT_SHA"],
    }
    slack_client.files_upload(channels: POST_CHANNEL,
                              file: Faraday::UploadIO.new("/tmp/visual.log",
                                                          "text/plain"),
                              title: "実行結果",
                              filename: "visual.log",
                              initial_comment: comment.inspect)
    break
  end
end
