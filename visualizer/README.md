# visualizer

## 使用方法

1. visualizer/app.rbを開いて、入力ファイル名(*.jsons)を書き換える
1. gem i sinatra
1. bundle exec ruby app.rb
1. open http://localhost:4567

## 入力仕様

.jsonsファイルは以下のような形式です。

- 1行目：ゲーム開始時のJSONデータ ({"punter":1, ...)
- 2行目以降：ゲームの各ターンのJSONデータ ({"move":, ...)
- 最終行：ゲーム終了時のJSONデータ ({"stop":, ...)
