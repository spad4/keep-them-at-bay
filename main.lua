local dandelion = require("dandelion")
local util_ex = require("util_ex")

H_SIZE = 16
PLAYER_SPEED = 30
ZOMBIE_SPEED = 2
ZOMBIE_W_ADJUST = 5
ZOMBIE_H_ADJUST = 6

WEAPONS = {
  {
    id = 0,
    fire_rate = 20,
    damage = 4,
    bullets = 1,
    ammo = 10,
    recoil = 0.5,
    spread = 15,
    reload = 2
  }
}


local function between(v, low, high)
  return v <= high and v >= low
end

local function cross_product(x1, x2, y1, y2)
  return x1 * y2 - y1 * x2
end

local function equal_points(x1, y1, x2, y2)
  return x1 == x2 and y1 == y2
end

local function all_equal(...)
  local arg = { ... }

  if #arg > 0 then
    local value = arg[1]
    for i, v in pairs(arg) do
      if v ~= value then
        return false
      end
    end
  end

  return true
end

local function lines_intersect(x1, y1, x2, y2, x3, y3, x4, y4)
  local px, py = x1, y1
  local rx, ry = x2 - x1, y2 - y1

  local qx, qy = x3, y3
  local sx, sy = x4 - x3, y4 - y3

  local dx, dy = qx - px, qy - py

  local t = cross_product(dx, dy, sx, sy) / cross_product(rx, ry, sx, sy)
  local u = cross_product(dx, dy, rx, ry) / cross_product(rx, ry, sx, sy)

  local rxs = cross_product(rx, ry, sx, sy)
  local dxr = cross_product(dx, dy, rx, ry)

  if rxs == 0 and dxr == 0 then -- lines are collinear
    -- points are touching
    if (equal_points(px, py, qx, qy) or equal_points(x2, y2, qx, qy) or equal_points(px, py, x4, y4) or equal_points(x3, y3, x4, y4)) then
      return true
    end

    -- check if lines overlap
    return not all_equal(x3 - x1 < 0, x3 - x2 < 0, x4 - x1 < 0, x4 - x2 < 0)
        or not all_equal(y3 - y1 < 0, y3 - y2 < 0, y4 - y1 < 0, y4 - y2 < 0)
  elseif rxs == 0 and dxr ~= 0 then -- lines are parallel
    return false
  elseif rxs ~= 0 then
    return between(t, 0, 1) and between(u, 0, 1)
  end

  return false
end

local function line_rect_overlap(l, r)
  local top    = { x1 = r.x, x2 = r.x + r.w, y1 = r.y, y2 = r.y }
  local left   = { x1 = r.x, x2 = r.x, y1 = r.y, y2 = r.y + r.h }
  local right  = { x1 = r.x + r.w, x2 = r.x + r.w, y1 = r.y, y2 = r.y + r.h }
  local bottom = { x1 = r.x, x2 = r.x + r.w, y1 = r.y + r.h, y2 = r.y + r.h }

  return lines_intersect(l.x1, l.y1, l.x2, l.y2, top.x1, top.y1, top.x2, top.y2)
      or lines_intersect(l.x1, l.y1, l.x2, l.y2, left.x1, left.y1, left.x2, left.y2)
      or lines_intersect(l.x1, l.y1, l.x2, l.y2, right.x1, right.y1, right.x2, right.y2)
      or lines_intersect(l.x1, l.y1, l.x2, l.y2, bottom.x1, bottom.y1, bottom.x2, bottom.y2)
end



function _config()
  ---@type Usagi.Config
  return { name = "Keep Them At Bay", game_id = "com.spad.keep_them_at_bay" }
end

function _init()
  -- Live reload preserves globals across saved edits but resets locals.
  -- Stash mutable game state in a capitalized global like `State` so it
  -- survives reloads; F5 calls _init again to reset.
  State = {}
  Zombies = {}
  Player = {
    x = 10,
    y = 134,
    health = 100,
    flip = false,
    moving = false,
    current_frame = 0,
    frame_time = 0
  }
  PlayerSkin = math.random(0, 3)
  MouseAngle = 0
  MouseDistance = 0
  FireCooldown = 0
  Weapon = WEAPONS[1]
  Ammo = Weapon.ammo
  Reloading = false
  ReloadStart = 0
  input.set_mouse_visible(false)
end

local function spawn_zombie()
  local new_zombie = {}
  new_zombie.x = math.random(10, usagi.GAME_W - 10)
  new_zombie.y = math.random(-40, -20)
  -- new_zombie.y = 30
  new_zombie.last_move = usagi.elapsed;
  new_zombie.move_delay = 0.5 + math.random() * 0.25
  new_zombie.moved = false
  new_zombie.health = 20
  new_zombie.current_frame = 1
  new_zombie.flip = math.random() > 0.5 and true or false
  new_zombie.w = 5
  new_zombie.h = 10
  new_zombie.kb_x = 0
  new_zombie.kb_y = 0
  table.insert(Zombies, new_zombie)
end

local function hit_zombie(x1, y1, x2, y2)
  local line = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }

  -- find all zombies that intersect with the line
  local can_hit = {}
  for _, zombie in pairs(Zombies) do
    local rect = { x = zombie.x + ZOMBIE_W_ADJUST, y = zombie.y + ZOMBIE_H_ADJUST, w = zombie.w, h = zombie.h }
    if line_rect_overlap(line, rect) then
      table.insert(can_hit, zombie)
    end
  end

  if #can_hit == 0 then return nil end

  local closest_index = 1
  local closest_distance = util.vec_dist({x=x1, y=y1}, {x=can_hit[1].x + ZOMBIE_W_ADJUST + 3, y=can_hit[1].y + ZOMBIE_H_ADJUST + 3})
  -- get the closest one out of the hits
  for i, zombie in pairs(can_hit) do
    local distance = util.vec_dist({x=x1, y=y1}, {x=zombie.x + ZOMBIE_W_ADJUST + 3, y=zombie.y + ZOMBIE_H_ADJUST + 3})
    if distance < closest_distance then
      closest_distance = distance
      closest_index = i
    end
  end

  return can_hit[closest_index], closest_distance
end

local function shoot()
  local vec = util.vec_from_angle(MouseAngle, 7)
  local adjusted_spread = Weapon.spread * 0.01
  local adjusted_x, adjusted_y = Player.x + 8, Player.y + 10

  Ammo -= 1

  for i = 1, Weapon.bullets do
    local spread = math.random() * adjusted_spread - adjusted_spread / 2

    -- calculates the hitbox of the bullet
    local start_x, start_y = adjusted_x + vec.x, adjusted_y + vec.y
    local spread_vec = util.vec_from_angle(MouseAngle + spread, 500)
    local end_x, end_y = start_x + spread_vec.x, start_y + spread_vec.y

    local zombie, distance = hit_zombie(start_x, start_y, end_x, end_y)
    if zombie then
      zombie.health -= Weapon.damage

      -- knockback
      local scaled_damage = Weapon.damage / 10
      local kb_x = math.floor(vec.x * scaled_damage)
      local kb_y = math.floor(vec.y * scaled_damage)
      if math.abs(kb_x) > math.abs(zombie.kb_x) then
        zombie.kb_x = kb_x
      end
      if math.abs(kb_y) > math.abs(zombie.kb_y) then
        zombie.kb_y = kb_y
      end
      
      dandelion.hitscan_bullet(start_x, start_y,
      { ["config"] = { length = distance, rotation = MouseAngle + spread } })
    else
      dandelion.hitscan_bullet(start_x, start_y,
        { ["config"] = { length = 1000, rotation = MouseAngle + spread } })
    end

  end

  dandelion.spent_bullet(adjusted_x, adjusted_y, { flip = Player.flip and 1 or -1 })
  effect.screen_shake(0.1, Weapon.recoil)
  FireCooldown = Weapon.fire_rate
end

function _update(dt)
  if FireCooldown > 0 then
    FireCooldown -= 1
  end

  if Reloading and usagi.elapsed - ReloadStart > Weapon.reload then
    Reloading = false
    Ammo = Weapon.ammo
  end

  local mx, my = input.mouse()
  local dx, dy = mx - Player.x - 8, my - Player.y - 11
  local h = util.vec_dist({ x = 0, y = 0 }, { x = dx, y = dy })
  local theta = math.asin(dy / h)
  MouseAngle = dx > 0 and theta or (math.pi - theta)
  MouseDistance = h
  GunAngle = dx > 0 and theta or (math.pi - theta)
  Player.flip = dx < 0 and true or false

  for i = #Zombies, 1, -1 do
    local zombie = Zombies[i]

    if zombie.health <= 0 then
      -- zombie died
      table.remove(Zombies, i)
    else
      local elapsed = usagi.elapsed

      if zombie.kb_x ~= 0 then -- weapon stun
        local direction = zombie.kb_x > 0 and 1 or -1
        zombie.kb_x = util.approach(zombie.kb_x, 0, 1)
        zombie.x += direction
        zombie.last_move = elapsed - zombie.move_delay * 0.5
      end
      if zombie.kb_y ~= 0 then -- weapon stun
        local direction = zombie.kb_y > 0 and 1 or -1
        zombie.kb_y = util.approach(zombie.kb_y, 0, 1)
        zombie.y += direction
        zombie.last_move = elapsed - zombie.move_delay * 0.5
      end
      
      if elapsed - zombie.last_move > zombie.move_delay then -- normal walking
        zombie.y += ZOMBIE_SPEED
        zombie.moved = true
        zombie.last_move = elapsed
        zombie.current_frame = util.wrap(zombie.current_frame + 1, 0, 2)
      end
    end
  end

  if input.key_pressed(input.KEY_H) then
    spawn_zombie()
  end

  local should_move = false
  if input.key_held(input.KEY_A) then
    Player.x = util.clamp(Player.x - PLAYER_SPEED * dt, 0, 309)
    if Player.moving == false then
      Player.frame_time = 0
    end
    should_move = true
  end

  if input.key_held(input.KEY_D) then
    Player.x = util.clamp(Player.x + PLAYER_SPEED * dt, 0, 309)
    if Player.moving == false then
      Player.frame_time = 0
    end
    should_move = true
  end

  Player.moving = should_move

  if input.mouse_held(input.MOUSE_LEFT) then
    if FireCooldown == 0 then
      if Ammo > 0 then
        shoot()
      end
      if Ammo < 1 and not Reloading then
        Reloading = true
        ReloadStart = usagi.elapsed
      end
    end
  end
end

local function draw_zombies()
  for i, zombie in pairs(Zombies) do
    if zombie.moved then
      gfx.sspr_ex(384, zombie.current_frame * H_SIZE, H_SIZE, H_SIZE, zombie.x, zombie.y, H_SIZE, H_SIZE, zombie.flip,
        false, 0, gfx.COLOR_TRUE_WHITE, 1)
    end
  end
end

local function draw_player()
  -- adjust to accommodate player skin
  local offset = PlayerSkin * H_SIZE

  -- used for arm recoil
  local vec = util.vec_from_angle(MouseAngle, 1)
  local m = Weapon.fire_rate - FireCooldown < 4 and -1 or 0

  -- player body
  --- body animations
  if Player.frame_time > 0 then
    Player.frame_time -= 1
  end

  if Player.frame_time == 0 then
    if Player.moving then
      Player.current_frame = util.wrap(Player.current_frame + 1, 1, 3)
    else
      Player.current_frame = 0
    end
    Player.frame_time = 10
  end

  gfx.sspr_ex(320 + offset, H_SIZE * Player.current_frame, H_SIZE, H_SIZE, Player.x, Player.y, H_SIZE, H_SIZE,
    Player.flip, false, 0, gfx.COLOR_TRUE_WHITE, 1)

  -- arms
  gfx.sspr_ex(320 + offset, 48, H_SIZE, H_SIZE, Player.x + m * vec.x, Player.y + m * vec.y, H_SIZE, H_SIZE, false,
    Player.flip, MouseAngle, gfx.COLOR_TRUE_WHITE, 1)

  -- gun
  gfx.sspr_ex(Weapon.id * 16, 192, H_SIZE, H_SIZE, Player.x + m * vec.x, Player.y + 2 + m * vec.y, H_SIZE, H_SIZE, false,
    Player.flip, GunAngle, gfx.COLOR_TRUE_WHITE, 1)
end

local function draw_cursor()
  local mx, my = input.mouse()

  local adjusted_spread = (MouseDistance / 150) * Weapon.spread / 2

  gfx.line(mx + adjusted_spread + 1, my, mx + adjusted_spread + 3, my, gfx.COLOR_WHITE)
  gfx.line(mx - (adjusted_spread + 2), my, mx - (adjusted_spread + 4), my, gfx.COLOR_WHITE)
  gfx.line(mx, my + (adjusted_spread + 2), mx, my + (adjusted_spread + 4), gfx.COLOR_WHITE)
  gfx.line(mx, my - (adjusted_spread + 1), mx, my - (adjusted_spread + 3), gfx.COLOR_WHITE)
end

local function draw_ammo()

  local text = Ammo .. "/" .. Weapon.ammo

  if Reloading then
    text = "Reloading... " .. text
  end

  local size = #text * 6

  gfx.text(text, 317 - size, 167, gfx.COLOR_DARK_GRAY)
  gfx.text(text, 316 - size, 166, gfx.COLOR_WHITE)

end

function _draw(dt)
  gfx.clear(gfx.COLOR_BLACK)

  -- background
  gfx.sspr_ex(0, 0, 320, 180, 0, 0, 320, 180, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
  draw_zombies()

  -- gfx.text("Day: 1", 4, 157, gfx.COLOR_DARK_GRAY)
  -- gfx.text("Day: 1", 4, 156, gfx.COLOR_WHITE)
  -- gfx.text("Forecast: Clear", 4, 167, gfx.COLOR_DARK_GRAY)
  -- gfx.text("Forecast: Clear", 4, 166, gfx.COLOR_WHITE)
  -- gfx.text("0/10", 293, 167, gfx.COLOR_DARK_GRAY)
  -- gfx.text("0/10", 293, 166, gfx.COLOR_WHITE)

  dandelion.Draw()
  draw_player()
  draw_ammo()
  draw_cursor()
end
