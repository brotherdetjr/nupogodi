pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- a tribute to "nu, pogodi!" -
-- soviet clone of nintendo eg-26

function _init()
  ctrl_mode = 1
  init()
end

function init()
  ---------------
  -- constants --
  ---------------

  states = {
    game = {update = update_game, draw = draw_game},
    game_over = {update = update_game_over, draw = draw_game_over}
  }
  
  ctrl_modes = {
    {
      handler = ctrl_arrows,
      sprite = {sx = 88, sy = 17}
    },
    {
      handler = ctrl_classic,
      sprite = {sx = 105, sy = 17}
    }
  }

  -- tl - top left, etc
  pos = {tl = 0, tr = 1, bl = 2, br = 3}
  pos_count = 4

  egg_spr = {
    {sx = 72, sy = 0, sw = 4, sh = 5, dx = 9, dy = 45},
    {sx = 76, sy = 0, sw = 5, sh = 4, dx = 13, dy = 49},
    {sx = 81, sy = 0, sw = 4, sh = 5, dx = 18, dy = 51},
    {sx = 85, sy = 0, sw = 5, sh = 5, dx = 22, dy = 54},
    {sx = 90, sy = 0, sw = 5, sh = 4, dx = 26, dy = 60}
  }
  
  chicken_spr = {
    {sx = 69, sy = 20, sw = 4, sh = 6, dx = 2, dy = 92},
    {sx = 73, sy = 20, sw = 5, sh = 6, dx = 9, dy = 92},
    {sx = 78, sy = 20, sw = 4, sh = 6, dx = 17, dy = 91},
    {sx = 82, sy = 20, sw = 6, sh = 6, dx = 21, dy = 88}
  }

  -- egg position internally ranges from -inf to 1.
  -- if it belongs to [0; 1) the egg is on the tray.
  -- egg_ticks is a number of sprite frames of an egg
  egg_ticks = #egg_spr
  -- we don't want the eggs to come too densely
  egg_gap_min = 1 / egg_ticks
  -- not exactly the max gap between the eggs, but a part of it
  egg_gap_max = egg_gap_min * 3

  hands_spr = {
    [pos.tl] = {sx = 0, sy = 0, sw = 18, sh = 15, dx = 30, dy = 58},
    [pos.tr] = {sx = 39, sy = 0, sw = 16, sh = 14, dx = 83, dy = 59},
    [pos.bl] = {sx = 18, sy = 0, sw = 21, sh = 17, dx = 27, dy = 77},
    [pos.br] = {sx = 55, sy = 0, sw = 17, sh = 12, dx = 81, dy = 80}
  }

  snd = {
    -- 0..3 - rolling eggs sound
    catch = 4,
    miss = 5,
    game_over = 6,
    chicken = 7
  }

  -- max number of eggs we process.
  -- not all of them will be visible on the tray
  max_eggs = 10
  -- speed increases with every caught egg
  speed_inc = 0.00002
  -- slow down the game for a while after a miss.
  -- stun variable is set to 1 and gets decremented
  -- every frame until it's 0
  stun_dec = 0.02
  -- lower the basket after an egg is caught.
  -- just_caught variable is set to 1 and gets decremented
  -- every frame until it's 0
  caught_dec = 0.2
  lives_total = 3
  chicken_probability = 0.3

  ---------------------
  -- state variables --
  ---------------------

  lives = lives_total
  score = 0
  speed = 0.011
  stun = 0
  chicken_running = false
  last_broken_egg = nil
  just_caught = 0
  wolf_pos = pos.tl
  -- the list of existing eggs.
  -- every egg is a table (a record)
  -- of {tray = ..., pos = ...}
  eggs = {}
  state(states.game)
end

function state(s)
  _update = s.update
  _draw = s.draw
end

function update_game()
  move_wolf()
  if (just_caught > 0) just_caught -= caught_dec
  if stun > 0 then
    stun -= stun_dec
    if (chicken_cheeping()) sfx(snd.chicken)
  end
  if stun <= 0 then
    if lives > 0 then
      roll_eggs()
    else
      state(states.game_over)
      sfx(snd.game_over)
    end
  end
  update_aux()
end

function update_game_over()
  move_wolf()
  update_aux()
end

function update_aux()
  if (btnp(4)) init()
  if (btnp(5)) ctrl_mode = ctrl_mode % #ctrl_modes + 1
end

function move_wolf()
  ctrl_modes[ctrl_mode].handler()
end

function ctrl_arrows()
		if (btn(0) and not btn(1)) wolf_pos = band(wolf_pos, 2)
		if (btn(1) and not btn(0)) wolf_pos = bor(wolf_pos, 1)
		if (btn(2) and not btn(3)) wolf_pos = band(wolf_pos, 1)
		if (btn(3) and not btn(2)) wolf_pos = bor(wolf_pos, 2)
end

function ctrl_classic()
  local b = band(btn(), 15)
  if b == 1 then
    wolf_pos = pos.bl
  elseif b == 2 then
    wolf_pos = pos.tr
  elseif b == 4 then
    wolf_pos = pos.tl
  elseif b == 8 then
    wolf_pos = pos.br
  end
end

function chicken_cheeping()
  if (not chicken_running) return false
  local prev = stun + stun_dec
  return prev == 1 or chicken_idx(prev) > chicken_idx(stun)
end

function roll_eggs()
  foreach(eggs, roll_egg)
  if #eggs > 0 then
    if (eggs[1].pos >= 1) drop_egg()
  else
    add_egg()
  end
end

function drop_egg()
  local t = eggs[1].tray
  deli(eggs, 1)
  if t == wolf_pos then
    update_catch()
  else
    update_miss(t)
  end
end

function update_catch()
  score += 1
  just_caught = 1
  speed += speed_inc
  while (#eggs < max_eggs) do
    add_egg()
  end
  sfx(snd.catch)
end

function update_miss(tray)
  lives -= 1
  stun = 1
  chicken_running = rnd() > 1 - chicken_probability
  last_broken_egg = tray
  eggs = {}
  sfx(snd.miss)
end

function add_egg()
  local p = -(speed / 2)
  if #eggs > 0 then
    p = min(p, eggs[#eggs].pos - rnd(egg_gap_max) - egg_gap_min)
  end
  add(eggs, {tray = flr(rnd(pos_count)), pos = p})
end

function roll_egg(e)
  i = egg_idx(e)
  e.pos += speed
  if (e.pos >= 0 and e.pos < 1 and egg_idx(e) > i) sfx(e.tray)
end

function egg_idx(e)
  return flr(e.pos * egg_ticks)
end

function draw_game()
  draw_common()
  draw_eggs()
end

function draw_game_over()
  draw_common()
  print("game over!", 46, 38, 7)
end

function draw_common()
  cls(6)
  draw_env()
  draw_hens()
  draw_wolf()
  draw_lives()
  draw_bottom()
  if stun > 0 then
    draw_broken_egg()
    draw_chicken()
  end
  print("score:"..score, 2, 2, 7)
end

function draw_env()
  for t = 0, 3 do
    tspr(95, 0, 24, 17, 2, 49, t)
  end
  for t = 2, 3 do
    tspr(49, 14, 20, 28, 2, 53, t)
  end
  sspr(69, 26, 14, 3, 40, 98)
  sspr(69, 26, 14, 3, 69, 97)
  sspr(69, 29, 14, 4, 46, 102)
  sspr(69, 29, 14, 4, 81, 102, -14, 4)
end

function draw_hens()
  local laid = {
    [pos.tl] = false,
    [pos.tr] = false,
    [pos.bl] = false,
    [pos.br] = false
  }
  for e in all(eggs) do
    if (e.pos >= 0 and e.pos < egg_gap_min) laid[e.tray] = true
  end
  for t = 0, pos_count - 1 do
    if laid[t] then
      tspr(80, 5, 12, 12, 2, 37, t)
    else
      tspr(72, 5, 8, 15, 2, 34, t)
    end
  end
end

function draw_wolf()
  if band(wolf_pos, 1) == 0 then
    sspr(0, 17, 25, 37, 44, 58) -- facing left
  else
    sspr(25, 17, 24, 37, 58, 58) -- facing right
  end
  local h = hands_spr[wolf_pos]
  local dy = h.dy
  if (just_caught > 0) dy += 1
  sspr(h.sx, h.sy, h.sw, h.sh, h.dx, dy)
end

function draw_lives()
  for l = 1, lives_total do
    local sy = l <= lives and 0 or 5
    sspr(119, sy, 8, 5, 127 - l * 9, 2)
  end
end

function draw_bottom()
  local s = ctrl_modes[ctrl_mode].sprite
  sspr(s.sx, s.sy, 17, 11, 2, 115)
  print("🅾️ to restart", 27, 115, 7)
  print("❎ to switch control mode", 27, 121, 7)
end

function draw_eggs()
  for e in all(eggs) do
    if e.pos >= 0 and e.pos < 1 then
      local s = egg_spr[egg_idx(e) + 1]
      tspr(s.sx, s.sy, s.sw, s.sh, s.dx, s.dy, e.tray)
    end
  end
end

function draw_broken_egg()
  tspr(119, 0, 8, 5, 24, 95, last_broken_egg % 2)
end

function draw_chicken()
  if chicken_running then
    local s = chicken_spr[chicken_idx(stun)]
    tspr(s.sx, s.sy, s.sw, s.sh, s.dx, s.dy, last_broken_egg % 2)
  end
end

function chicken_idx(s)
  return ceil(s * #chicken_spr)
end

function tspr(sx, sy, sw, sh, dx, dy, tray)
  local dw = sw
  if tray % 2 == 1 then
    dx = 128 - dx
    dw = -dw
  end
  if (tray > 1) dy += 21
  sspr(sx, sy, sw, sh, dx, dy, dw, sh)
end

__gfx__
00001110000000000000000000000011111000000000000111000001111101111100000000100111001100011011110222222220000000000000000170000100
00011111001100000000000000111100100111100001111011100000110110001111000001711777117100177117711222222222000000000000000177901710
00110010110010000000000011000001011100100111001110110000001000010101100017711771017711777117771000000022220000000000000017797710
00110001001001000000000100000110100011011000011010110001100110011101100017710110017711171001110000000000222000000000000001197100
00110010101101000000000100101011000100000111001110110000111001110100110001100000001100111000000000000000022220000000000000990000
00111001010001000000000011110100001000000000110010110000100100011110110000200000700000002000000000000000000222000000000500000500
00011000111000100000000110011000010000000000011111111100010011111111111102200000770000222200000000000000000022200000000050505050
00011111111110100000000110110000100000000001111111111110001000000111111122770000770000277700000000000000000002222000000505050500
00111111100111010000001100110000100000000001110011111110000100001001111007007770077007700070000000000000000000022200000050505000
01110011100111010001111111111001000000000001110011001100000010010011111070007700707770007070000000000000000000002222000005050000
11111001110010110011111111111110000000000000111010010100000001101111110070070722070000000077000000000000000000002222200000000000
01110100000011000011111111111110000000000000111000011000000000111111100007000072700000007700000000000000000000002202220000000000
00111000000000110011111111111110000000000111000000001000000000000000000007000070070000072000000000000000000000002200222000000000
00011100011110001101111111111110000000011111111111110000000000000000000007000007700700722000000000000000000000002200022000000000
00000111100001110000111111111100000000000000000000022022000000000000000077000007000707700000000000000000000000002200000000000000
00000000000000000000011111111000000000000000000000022022000000000000000070707007077070000000000000000000000000002200000000000000
00000000000000000000000011000000000000000000000000022022022000000000000077700707777700000000000000000000000000002200000000000000
00000000000000000000100000000000011000000000000000022022022000000000000070707707000000000000000555000000055000000000000055000000
00000000000000000001010000000000010100110000000000022022022022000000000077077070000000000000005505500000050055000000055005000000
00000000011110100010010000000000100011010010000000000000022022000000000077777700000000000000005000500000000555500000555500000000
00000001101111110101010000000000100101111111100001515100022022022000009900990099000990000000005555500000000555500000555500000000
00000000111111111010010000000000010101111111000005151515100022022000029902990099202990900000000555000000000055000000055000000000
00000000101111110010100000000001110101111111100001515151500022022000009000090909000099000000000000000000000000000000000000000000
00000000010000111100110000000001111111100011110005151515151500022000009990999099990999990555000555000555000055000000055000000000
00001100001101101111110000000001011110011001010001515151515151522000099900099009900009025505505555505505500555500000555500000000
00001111011010110111010000000010111100101111000115151515150515150000002020200202020020005005505000505500500555500000555500000000
00010000101111010111101000000011011110101010011111515151500151515000001010050500001000005505505505505505550055000000055005000000
00010000011101000111010000000010011100000111100115151515101515151000015151515151515000000555000555000555055000000000000055000000
00001111000000001111010000000010111110010000000011515151505151515000001515150015150000000000000000000000000000000000000000000000
00001000111100001111000000000000111100001110000015151515101515150000000000000500001000000000000000000000000000000000000000000000
00000111001111011100000000000000001110110011101101015151510101510000015100505101515000000000000000000000000000000000000000000000
00000000110001000100000000000000011000101100111000001000000000000000051515151515151000000000000000000000000000000000000000000000
00000000000110000110000000000000011000010011000000000000000000000000000051510150000000000000000000000000000000000000000000000000
00000000000100001100000000000000001100011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001000011000000000000000001100011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011000110000000000000000000110001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011011100000000000000010000111001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111100001000001100101100011111100000000000010000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111100011000001110100110011111100000000515151500151500001000000000000000000000000000000000000000000000000000000000000
00000001111111111101000001101100111111111100000005151515151515151515100000000000000000000000000000000000000000000000000000000000
00000010111111101010000001100101110111111110000001515151515151515151000000000000000000000000000000000000000000000000000000000000
00001100000000001100000000110101101001111111000005001005001010001500000000000000000000000000000000000000000000000000000000000000
00110010100110100110000000010011010100011001000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01001101011011011001100000011001001010100000100000000000000000000000000000000000000000000000000000000000000000000000000000000000
01110011111100110000010000001001000111010110011000000000000000000000000000000000000000000000000000000000000000000000000000000000
10001100000000001100010000000110000001111110000100000000000000000000000000000000000000000000000000000000000000000000000000000000
01100011000000000010100000000000000000000010111110000000000000000000000000000000000000000000000000000000000000000000000000000000
00011000100000000101011100000000000000000111100010000000000000000000000000000000000000000000000000000000000000000000000000000000
00000110010000001001100010000000000000011000011100000000000000000000000000000000000000000000000000000000000000000000000000000000
01110001001000001010000100000000000001100111110000000000000000000000000000000000000000000000000000000000000000000000000000000000
10111110100100010100011000000000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000011100010001100000000000000100011111110000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011111110000001110000000000000000011100000011100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66677667766776777677766666777677766666666666666666666666666666666666666666666666666666666666666666665666665661766661661766661666
66766676667676767676666766766676766666666666666666666666666666666666666666666666666666666666666666666565656561779617161779617166
66777676667676776677666666777677766666666666666666666666666666666666666666666666666666666666666666665656565666177977166177977166
66667676667676767676666766667666766666666666666666666666666666666666666666666666666666666666666666666565656666611971666611971666
66776667767766767677766666777666766666666666666666666666666666666666666666666666666666666666666666666656566666669966666669966666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666626666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666622666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666772266
66766666662666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666777667666
66776666222266666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666677666766
66776666277766666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666662276766766
66677667766676666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666662766667666
66767776667676666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666766667666
66676666666677666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666667666667666
66766666667766666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666667666667766
66676666672666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666667667676766
66766766722116666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666667676677766
66666767761716666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666667677676766
66677676617716666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666767767766
66777766617716666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666677777766
66222222221166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666662222222266
66222222222666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666622222222266
66666666622226666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666662222666666666
66666666666222666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666622266666666666
66666666666622226666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666662222666666666666
66666666666666222666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666622266666666666666
66662666666666622266666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666222666666666626666
66622666666666662222666666666666666666666666666666666666666666666666666666666666666666666666666666666666666622226666666666622666
66227766666666666622266666666666666666666666666666666666666666666666666666666666666666666666666666666666666222666666666666772266
66676677766666666662222666666666666666666666666666666666666666661666666666666666666666666666666666666666622226666666666777667666
66766677666666666662222266666666666666666666666666666666666666616166666666666666666666666666666666666666222226666666666677666766
66766767226666666662262226666666666666666666666666666111161666166166666666666666666666666666666666666662226226666666662276766766
66676666726666666662266222666666666666666666666666611611111161616166666666666666666666666666666666666622266226666666662766667666
66676666766666666662266622666666666666666666666666661111111116166166666666666666666666666666666666666622666226666666666766667666
66676666676666666662266666666666666666666666666666661611111166161666666666666666666666666666666666666666666226666666667666667666
66776666676666666662266666666666666666666666666666666166661111661166666666666666666666666666666666666666666226666666667666667766
66767676676666666662266666666666666666666666666611666611611611111166666666666666666666666666666666666666666226666666667667676766
66777667676666666666666666666666666666666666666611116116161161116166666666666666666666666666666666666666666666666666667676677766
66767677676666666666666666666666666666666666666166661611116161111616666666666666666666666666666666666666666666666666667677676766
66776776766666666666666666666666666666666666666166666111616661116166666666666666666666666666666666666666666666666666666767767766
66777777666666666666666666666666666666666666666611116666666611116166666666666666666666666666666666666666666666666666666677777766
66222222226666666666666666666666666666666666666616661111666611116666666666666666666666666666666666666666666666666666662222222266
66222222222666666666666666666666666666666666666661116611116111666666666666666666666666666666666666666666666666666666622222222266
66666666622226666666666666666666666666666666666666661166616661666666666666666666666666666666666666666666666666666662222666666666
66666666666222666666666666666666666666666666666666666661166661166666666666666666666666666666666666666666666666666622266666666666
66662262266622226666666666666666666666666666666666666661666611666666666666666666666666666666666666666666666666662222666226226666
66662262266666222666666666666666666666666666666666666616666116666666666666666666666666666666666666666666666666622266666226226666
66662262262266622266666666666666666666666666666666666116661166666666666666666666666666666666666666666666666666222666226226226666
66662262262266662222666666666666666666611111666666666116111666666666666666666666666666666666666666666666666622226666226226226666
66662262262262266622266666666666666111166166111166661111111666616666666666666666666666666666666666666666666222666226226226226666
66666666662262266662222666666666611666661611166166661111111666116666666666666666666666666666666666666666622226666226226666666666
66151516662262262262222266666666166666116166611666611111111111616666666666666666666666666666666666666666222226226226226661515166
66515151516662262262262226111166166161611666166666161111111616166666666666666666666666666666666666666662226226226226661515151566
66151515156662262262266222177116611116166661666611666666666611666666666666666666666666666666666666666622266226226226665151515166
66515151515156662262266622177716116611666616661166161661161661166666666666666666666666666666666666666622666226226665151515151566
66151515151515152262266666611166116116666166616611616116116116611666666666666666666666666666666666666666666226225151515151515166
66515151515651515662266666666661166116666166611166111111661166666166666666666666666666666666666666666666666226651515651515151566
66151515156615151562266666661111111111661666166611666666666611666166666666666666666666666666666666666666666226515151665151515166
66515151516151515166666666611111111111116666611666116666666666161666666666666666666666666666666666666666666666151515161515151566
66151515156515151566666666611111111111116666666116661666666661616111666666666666666666666666666666666666666666515151565151515166
66515151516151515666666666611111111111116666666661166166666616611666166666666666666666666666666666666666666666651515161515151566
66161515151616151666666666661111111111116666611166616616666616166661666666666666666666666666666666666666666666615161615151516166
66666166666666666666666666666111111111166666161111161661666161666116666666666666666666666666666666666666666666666666666666166666
66666666666666666666666666666611111111666666611666666111666166611666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666611666666666666111111166666611166666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666661666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666616666666
66651515156615156666166666666666666666666666666666666666666666666666666666666666666666666666666666666666666166665151665151515666
66515151515151515151516666666666666666666666666666666666666666666666666666666666666666666666666666666666661515151515151515151566
66151515151515151515166666666666666666666666666666666666666666666666666666666666666666666666666666666666666151515151515151515166
66566166566161666156666666666666666666666666666666666666666666666666666666666666666666666666666666666666666665166616166566166566
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666

__sfx__
000300001b0301f03005030003000c6000b6000960019600196001960017600006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000270202d020100200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001d03025030140300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001b0301e030140300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000f07013070060701a70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000017160191600e1601500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000217700f070217700f070217700f070217700f070217700f070217700f070217700f070217700f07010700000001e000117001d0001870011700000000000000000000000000000000000000000000000
000300002075011050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
