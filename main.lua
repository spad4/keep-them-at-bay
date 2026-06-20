ZOMBIE_SPEED = 5

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
    y = 139,
    health = 100
  }
end

local function spawn_zombie()
  local new_zombie = {}
  new_zombie.x = math.random(10, usagi.GAME_W - 10)
  new_zombie.y = -10
  new_zombie.frame = 0
  new_zombie.health = 20
  table.insert(Zombies, new_zombie)
end

function _update(dt)
  if input.key_pressed(input.KEY_H) then
    spawn_zombie()
  end

  for i = #Zombies, 1, -1 do
    local zombie = Zombies[i]
    zombie.y += ZOMBIE_SPEED * dt
  end
end

local function draw_zombies()

  for i, zombie in pairs(Zombies) do
    gfx.spr(23, zombie.x, zombie.y)
  end

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

  -- player
  gfx.spr_ex(21, 64, 127, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
  gfx.spr_ex(22, 64, 127, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
end
