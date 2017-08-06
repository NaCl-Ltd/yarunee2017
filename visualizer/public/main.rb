include DXOpal
Window.width = 1000
Window.height = 600
COLORS = [
  C_GREEN,
  C_RED,
  C_MAGENTA,
  C_CYAN,
  [128, 128, 0],
  [128, 128, 128],
  C_BLACK,

  C_BLUE,
]
MARGIN = 5

done = false
Window.load_resources do
  Window.loop do
    asdf if done
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

      edges.each do |edge|
        src, tgt, owner = `edge[0]`, `edge[1]`, `edge[2]`
        x1 = `(nodes[src][0] - min_x) * scale` + MARGIN
        y1 = `(nodes[src][1] - min_y) * scale` + MARGIN
        x2 = `(nodes[tgt][0] - min_x) * scale` + MARGIN
        y2 = `(nodes[tgt][1] - min_y) * scale` + MARGIN

#        ctx = Window._img.ctx
#        rgba = Window._img.send(:_rgba, COLORS[owner][0,3])
#        a = %x{
#        console.debug(ctx);
#          ctx.beginPath();
#          ctx.strokeStyle = #{rgba};
#          ctx.moveTo(x1, y1); 
#          ctx.lineTo(x2, y2); 
#          ctx.stroke(); 
#        }
        Window.draw_line(x1, y1, x2, y2, COLORS[owner])
      end

      nodes.each do |node|
        x, y, is_mine = `node[0]`, `node[1]`, `node[2]`

        px = `(x - min_x) * scale` + MARGIN
        py = `(y - min_y) * scale` + MARGIN

        Window.draw_circle_fill(px, py, 
                                (is_mine ? 5 : 2),
                                (is_mine ? C_RED : C_BLACK))
      end

      done = true
    else
      Window.draw_font(0, 100, "Loading..", Font.default)
    end
  end
end

