include DXOpal
Window.width = 1000
Window.height = 600
COLORS = [
  [0,135,255],  # DodgerBlue1
  [255, 0, 0],  # red
  [0, 255, 0], # lime
  [255, 0, 255], # fuchsia

  [128, 0, 0], # maroon
  [128, 128, 0], # olive
  [135,0,255], #Purple
  [0, 255, 255], # aqua

  [0, 128, 128], #teal
  [0, 0, 128], #navy
  [128, 0, 128], #purple
  [128, 128, 128], #gray

  [255, 165, 0], #orange
  [192, 192, 192], #silver
  [200, 200, 0],
  [30, 30, 30],

  C_BLUE,
]
MARGIN = 5
INFO_FONT = Font.new(10)

mapData = `window.mapData`
width = mapData.JS[:width]
height = mapData.JS[:height]
end_turn = mapData.JS["game_progress"].size
scale_x = (Window.width - MARGIN*2) / width
scale_y = (Window.height - MARGIN*2) / height
scale = [scale_x, scale_y].min
min_x = mapData.JS["min_x"]
min_y = mapData.JS["min_y"]
nodes = mapData.JS["nodes"]

# 点をオフスクリーンレンダリングする
nodes_img = Image.new(Window.width, Window.height)
nodes.each do |node|
  x, y, is_mine = `node[0]`, `node[1]`, `node[2]`

  px = `(x - min_x) * scale` + MARGIN
  py = `(y - min_y) * scale` + MARGIN

  nodes_img.circle_fill(px, py, 
                        (is_mine ? 5 : 2),
                        (is_mine ? C_RED : C_BLACK))
end

edges_img = Image.new(Window.width, Window.height)


prev_turn_num = nil
turn_num = end_turn
Window.load_resources do
  Window.loop do
    Window.draw_box_fill(0, 0, Window.width, Window.height, [255, 255, 255])

    if Input.key_push?(K_RIGHT)
      turn_num += 1 if turn_num < end_turn
    end
    if Input.key_push?(K_LEFT)
      turn_num -= 1 if turn_num > 0
    end
    if Input.key_push?(K_A)
      turn_num = 0
    end
    if Input.key_push?(K_Z)
      turn_num = end_turn
    end

    if turn_num != prev_turn_num
      edges = Hash.new(mapData.JS["edges"])
      mapData.JS["game_progress"][0..turn_num].each do |turn|
        moves = `turn["move"]["moves"]`
        moves.each do |move|
          next unless move.JS["claim"]  # passの場合はスキップ
          claim = move.JS["claim"]
          id = claim.JS["punter"]
          src = claim.JS["source"]
          tgt = claim.JS["target"]
          if src < tgt
            edges[src.to_s][tgt.to_s] = id
          else
            edges[tgt.to_s][src.to_s] = id
          end
        end
      end
      # 辺を描画
      edges_img.box_fill(0, 0, Window.width, Window.height, [255, 255, 255])
      edges.each do |src, tgts|
        tgts.each do |tgt, owner|
          x1 = `(nodes[src][0] - min_x) * scale` + MARGIN
          y1 = `(nodes[src][1] - min_y) * scale` + MARGIN
          x2 = `(nodes[tgt][0] - min_x) * scale` + MARGIN
          y2 = `(nodes[tgt][1] - min_y) * scale` + MARGIN
          edges_img.line(x1, y1, x2, y2, COLORS[owner.to_i])
        end
      end
    end
    Window.draw(0, 0, edges_img)

    # 点を描画
    Window.draw(0, 0, nodes_img)

    # 情報を描画
    player_id = mapData.JS["player_id"]
    scores = mapData.JS["scores"]
    Window.draw_font(0, 0, "FPS: #{Window.real_fps}", INFO_FONT, color: C_BLACK)
    Window.draw_font(0, 10, `"turn: " + turn_num + " / " + end_turn`, INFO_FONT, color: C_BLACK)
    i = 2
    scores.each do |score|
      msg = `"player" + i + ": " + score;`
      if `i == player_id`
        `msg += " (you)"`
      end
      Window.draw_font(0, i*10, msg, INFO_FONT, color: COLORS[i-1])
      i+=1
    end

    prev_turn_num = turn_num
  end
end

