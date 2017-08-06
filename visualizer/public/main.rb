include DXOpal
Window.width = 1000
Window.height = 600
COLORS = [
  [0, 255, 0],  # green
  [255, 0, 0],  # red
  [0, 255, 255], # aqua
  [0, 255, 0], # lime

  [255, 0, 255], # fuchsia
  [128, 0, 0], # maroon
  [128, 128, 0], # olive
  [0, 128, 0], #lime

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

done = false
Window.load_resources do
  Window.loop do
    raise "ok" if done # DXOpalに一回だけ描画を行うようなAPIがまだないためraiseで止めている
    Window.draw_box_fill(0, 0, Window.width, Window.height, [255, 255, 255])
    Window.draw_font(0, 0, "FPS: #{Window.real_fps}", Font.default)
    
    if (mapData = `window.mapData`)
      width = mapData.JS[:width]
      height = mapData.JS[:height]
      scale_x = (Window.width - MARGIN*2) / width
      scale_y = (Window.height - MARGIN*2) / height
      scale = [scale_x, scale_y].min
      min_x = mapData.JS["min_x"]
      min_y = mapData.JS["min_y"]
      Window.draw_font(0, 100, "#{width} #{height}", Font.default)

      edges = mapData.JS["edges"]
      nodes = mapData.JS["nodes"]

      # 辺を描画
      edges.each do |edge|
        src, tgt, owner = `edge[0]`, `edge[1]`, `edge[2]`
        x1 = `(nodes[src][0] - min_x) * scale` + MARGIN
        y1 = `(nodes[src][1] - min_y) * scale` + MARGIN
        x2 = `(nodes[tgt][0] - min_x) * scale` + MARGIN
        y2 = `(nodes[tgt][1] - min_y) * scale` + MARGIN
        Window.draw_line(x1, y1, x2, y2, COLORS[owner])
      end

      # 点を描画
      nodes.each do |node|
        x, y, is_mine = `node[0]`, `node[1]`, `node[2]`

        px = `(x - min_x) * scale` + MARGIN
        py = `(y - min_y) * scale` + MARGIN

        Window.draw_circle_fill(px, py, 
                                (is_mine ? 5 : 2),
                                (is_mine ? C_RED : C_BLACK))
      end

      # スコア情報を描画
      player_id = mapData.JS["player_id"]
      scores = mapData.JS["scores"]
      i = 0
      scores.each do |score|
        msg = `"player" + i + ": " + score;`
        if `i == player_id`
          `msg += "*"`
        end
        Window.draw_font(0, i*10, msg, INFO_FONT, color: COLORS[i])
        i+=1
      end

      done = true
    else
      Window.draw_font(0, 100, "Loading..", Font.default, color: C_BLACK)
    end
  end
end

