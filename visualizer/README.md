# visualizer

## How to use

1. bundle install
1. bundle exec ruby app.rb
1. Open http://localhost:4567/?playlog=data/play_logs/nari/game_9072_tube.jsons

## Input data

Spec of .jsons file:

- First line: JSON of when the game was started (`{"punter":1, ...`)
- Second line~: JSON of the each turrn (`{"move":, ...`)
- Last line: JSON of when the game was end (`{"stop":, ...`)
