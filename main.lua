H_SIZE = 16
PLAYER_SPEED = 20
ZOMBIE_SPEED = 2

WEAPONS = {
  {
    fire_rate = 20,
    damage = 4,
    ammo = 10,
    shake = 0.5,
    spread = 10
  }
}

local dandelion = require("dandelion")

function _config()
  ---@type Usagi.Config
  return { name = "Game", game_id = "com.usagiengine.YOURGAMENAME" }
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
    flip = false
  }
  MouseAngle = 0
  MouseDistance = 0
  FireCooldown = 0
  Weapon = WEAPONS[1]
  input.set_mouse_visible(false)
end

local function spawn_zombie()
  local new_zombie = {}
  new_zombie.x = math.random(10, usagi.GAME_W - 10)
  new_zombie.y = math.random(-30, -10)
  new_zombie.last_move = usagi.elapsed;
  new_zombie.moved = false
  new_zombie.health = 20
  new_zombie.current_frame = 1
  new_zombie.flip = math.random() > 0.5 and true or false
  table.insert(Zombies, new_zombie)
end

local function shoot()

  local vec = util.vec_from_angle(MouseAngle, 7)
  local adjusted_spread = Weapon.spread * 0.01
  local spread = math.random() * adjusted_spread - adjusted_spread / 2
  dandelion.hitscan_bullet(Player.x + 8 + vec.x, Player.y + 11 + vec.y, {["config"] = {length = 1000, rotation = MouseAngle + spread}})
  dandelion.spent_bullet(Player.x + 8, Player.y + 11, {flip = Player.flip and 1 or -1})
  effect.screen_shake(0.1, Weapon.shake)
  FireCooldown = Weapon.fire_rate

end

function _update(dt)
  
  if FireCooldown > 0 then
    FireCooldown -= 1
  end

  local mx, my = input.mouse()
  local dx, dy = mx - Player.x - 8, my - Player.y - 11
  local h = util.vec_dist({x = 0, y = 0}, {x = dx, y = dy})
  local theta = math.asin(dy / h)
  MouseAngle = dx > 0 and theta or (math.pi - theta)
  MouseDistance = h
  GunAngle = dx > 0 and theta or (math.pi - theta)
  Player.flip = dx < 0 and true or false

  for i = #Zombies, 1, -1 do
    local zombie = Zombies[i]
    local elapsed = usagi.elapsed
    if elapsed - zombie.last_move > 1 then
      zombie.y += ZOMBIE_SPEED
      zombie.moved = true
      zombie.last_move = elapsed
      zombie.current_frame = util.wrap(zombie.current_frame + 1, 0, 2)
    end
  end
  
  if input.key_pressed(input.KEY_H) then
    spawn_zombie()
  end

  if input.key_held(input.KEY_A) then
    Player.x = util.clamp(Player.x - PLAYER_SPEED * dt, 0, 309)
  end

  if input.key_held(input.KEY_D) then
    Player.x = util.clamp(Player.x + PLAYER_SPEED * dt, 0, 309)
  end

  if input.mouse_held(input.MOUSE_LEFT) then
    if FireCooldown == 0 then
      shoot()
    end
  end
end

local function draw_zombies()

  for i, zombie in pairs(Zombies) do
    if zombie.moved then
      gfx.sspr_ex(352, zombie.current_frame * H_SIZE, H_SIZE, H_SIZE, zombie.x, zombie.y, H_SIZE, H_SIZE, zombie.flip, false, 0, gfx.COLOR_TRUE_WHITE, 1)
    end
  end

end

local function draw_player()
  gfx.sspr_ex(320, 0, H_SIZE, H_SIZE, Player.x, Player.y, H_SIZE, H_SIZE, Player.flip, false, 0, gfx.COLOR_TRUE_WHITE, 1)
  gfx.sspr_ex(336, 0, H_SIZE, H_SIZE, Player.x, Player.y, H_SIZE, H_SIZE, false, Player.flip, MouseAngle, gfx.COLOR_TRUE_WHITE, 1)
  gfx.sspr_ex(336, 16, H_SIZE, H_SIZE, Player.x, Player.y + 2, H_SIZE, H_SIZE, false, Player.flip, GunAngle, gfx.COLOR_TRUE_WHITE, 1)
end

local function draw_cursor()
  local mx, my = input.mouse()

  local adjusted_spread = (MouseDistance / 150) * Weapon.spread / 2

  gfx.line(mx + adjusted_spread + 1, my, mx + adjusted_spread + 3, my, gfx.COLOR_WHITE)
  gfx.line(mx - (adjusted_spread + 2), my, mx - (adjusted_spread + 4), my, gfx.COLOR_WHITE)
  gfx.line(mx, my + (adjusted_spread + 2), mx, my + (adjusted_spread + 4), gfx.COLOR_WHITE)
  gfx.line(mx, my - (adjusted_spread + 1), mx, my - (adjusted_spread + 3), gfx.COLOR_WHITE)

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
  draw_cursor()

end
