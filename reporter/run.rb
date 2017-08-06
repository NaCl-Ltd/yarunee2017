#!/usr/bin/env ruby

require "tempfile"
require "open-uri"
require "open3"
require "mechanize"

TOP_SRC_PATH = Pathname(__dir__).parent.exapand_path
STATUS_URI = URI("http://punter.inf.ed.ac.uk/status.html")
LAMDUCT_VERSION = "0.3"
LAMDUCT_URI = URI("https://raw.githubusercontent.com/icfpcontest2017/icfpcontest2017.github.io/master/static/lamduct-#{lamduct_version}")
LAMDUCT_PATH = TOP_SRC_PATH / "vendor/downloads/lamduct-#{lamduct_version}")
VISUAL_LOG_PATH = Pathname("/tmp/visual.log")
UPLOAD_CHANNEL = "test"

def run(*args)
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
    FileUtils.mv(f.path, LAMDUCT_PATH)
  end
end

# 接続先のポート番号を決定
ports = []
agent = Mechanize.new
page = agent.get(STATUS_URI)
page.css("tr").each do |tr|
  md = %r|Waiting for punters. (\d+)/(\d+)|.match(tr.css("td")[0].content)
  current_n_panters = md[0].to_i
  required_n_panters = md[0].to_i
  if current_n_panters + 1 == required_n_panters
    ports << tr.css("td")[3].content.to_i
  end
end

# lamductを実行
target_port = ports.sample
run(LAMDUCT_PATH.to_s, "--game-port=#{target_port}", "--log-level=3",
    (TOP_SRC_PATH / "punter").to_s)

# 実行結果をSlackへ投稿
Slack.configure do |c|
  c.token = ENV["SLACK_API_TOKEN"]
end
slack_client = Slack::Web::Client.new
slack_client.files_upload(channels: UPLOAD_CHANNEL,
                          file: Faraday::UploadIO.new("/tmp/visual.log",
                                                      "text/plain"),
                          title: "実行結果",
                          filename: "visual.log")
