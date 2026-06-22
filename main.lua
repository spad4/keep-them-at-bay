local dandelion = require("dandelion")
local ZOMBIES = require("zombies")
local TURRETS = require("turrets")
local UNLOCKS = require("unlocks")
local WEAPONS = require("weapons")
local GRENADES = require("grenades")

H_SIZE = 16
PLAYER_SPEED = 40
ZOMBIE_SPEED = 2
ZOMBIE_W_ADJUST = 5
ZOMBIE_H_ADJUST = 6
WALL_START = 140
PLAYER_HEALTH = 20

BULLETS = {
    ["rifle"] = {
        name = "rifle",
        spr_x = 321,
        spr_y = 177,
        spr_w = 1,
        spr_h = 8,
        particle = "rifle_casing"
    },
    ["shell"] = {
        name = "shell",
        spr_x = 323,
        spr_y = 177,
        spr_w = 2,
        spr_h = 8,
        particle = "shell_casing"
    }
}

function _config()
    ---@type Usagi.Config
    return { name = "Keep Them At Bay", game_id = "com.spad.keep_them_at_bay" }
end

local function shuffle(table)
    for i = #table, 2, -1 do
        local j = math.random(i)
        table[i], table[j] = table[j], table[i]
    end
    return table
end

local function reset()
    Zombies = {}
    WallZombies = {}
    Player = {
        x = 5,
        y = 134,
        health = PLAYER_HEALTH,
        last_health = PLAYER_HEALTH,
        flip = false,
        moving = false,
        current_frame = 0,
        frame_time = 0,
        last_hit = 0,
        kb = 0
    }
    Player_Skin = math.random(0, 3)
    Mouse_Angle = 0
    Mouse_Distance = 0
    Fire_Cooldown = 0
    Weapon = WEAPONS["rifle_weapon"]
    Ammo = Weapon.ammo
    Reloading = false
    Reload_Start = 0
    Walls = {}
    Turrets = {}
    Discovered_Turrets = { "rifle_turret_1" }
    Discovered_Upgrades = { ["rifle_turret_2"] = true }
    Highlighted_Turret = nil
    Selected_Turret = nil
    Day = 1
    Money = 200
    Is_Night = false
    Weather = "Clear"
    Game_Over = nil
    Game_Over_Phase = 0
    Zombies_Killed = 0
    Money_Made = 0
    Current_Wave = {}
    Transition_Started = 0
    Drawer = false
    Drawer_Type = nil
    Drawer_Height = 0
    Drawer_Items = {}
    Highlighted_Drawer_Item = nil
    Highlighted_Tab = nil
    Potential_Unlocks = {
        "frag_grenade", "shotgun_weapon", "sniper_weapon", "burst_weapon", "shotgun_turret", "sniper_turret",
        "ice_turret", "molotov", "rifle_turret_3",
    }
    Potential_Mutations = {
        "sprinter_1", "shambler_2", "boomer_1", "conjoined_1"
    }
    -- Potential_Mutations = shuffle(Potential_Mutations)
    -- Potential_Unlocks = shuffle(Potential_Unlocks)
    Next_Is_Unlock = true
    Choice_1 = nil
    Choice_2 = nil
    Choice_Type = nil
    Choice_Progression = 0
    Highlighted_Choice = 0
    Discovered_Mutations = { "shambler_1" }
    Discovered_Weapons = {
        ["rifle_weapon"] = true
    }
    Discovered_Grenades = {}
    Grenade_Inventory = {}
    Grenades = {}
    Grenade_Slots = 1
    for i = 1, 20 do
        Walls[i] = 100
    end
    for i = 1, 16 do
        Turrets[i] = false
    end
    dandelion.ClearAll()
    gfx.shader_set(nil)
end

function _init()
    reset()
    Screen_Shake = true
    dandelion.ClearAll()
    input.set_mouse_visible(false)
    gfx.shader_set("zombie_eyes")
end

local function conditional_screen_shake(time, intensity)
    if Screen_Shake then
        effect.screen_shake(time, intensity)
    end
end

local function spawn_zombie(type, x, y, on_wall)
    local model = ZOMBIES[type]

    local new_zombie = {}
    new_zombie.type = type
    new_zombie.x = x
    new_zombie.y = y
    new_zombie.count = model.count or 0
    new_zombie.spr_x = model.spr_x
    new_zombie.spr_y = model.spr_y
    -- new_zombie.y = 100
    new_zombie.last_move = usagi.elapsed;
    new_zombie.moved = true
    new_zombie.current_frame = 1
    new_zombie.flip = math.random() > 0.5 and true or false
    new_zombie.kb_x = 0
    new_zombie.kb_y = 0
    new_zombie.on_wall = false
    new_zombie.w = model.w
    new_zombie.h = model.h
    new_zombie.health = model.health * (math.random() * 0.5 + 0.75)
    new_zombie.move_delay = model.move_delay * (math.random() * 0.25 + 0.75)
    new_zombie.money = model.money
    new_zombie.damage = model.damage
    new_zombie.variant = math.random(0, model.variants - 1)
    new_zombie.on_wall = on_wall
    table.insert(Zombies, new_zombie)
end

local function apply_knockback_zombie(zombie, x, y)
    local kb_x = math.floor(x)
    local kb_y = math.floor(y)
    if math.abs(kb_x) > math.abs(zombie.kb_x) then
        zombie.kb_x = kb_x
    end
    if math.abs(kb_y) > math.abs(zombie.kb_y) then
        zombie.kb_y = kb_y
    end
end


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

local function hit_zombie(x1, y1, x2, y2)
    local line = { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }

    -- find all zombies that intersect with the line
    local can_hit = {}
    for _, zombie in pairs(Zombies) do
        if zombie.y <= WALL_START - 8 or zombie.on_wall then -- zombies past the wall cannot be shot
            local rect = { x = zombie.x + ZOMBIE_W_ADJUST, y = zombie.y + ZOMBIE_H_ADJUST, w = zombie.w, h = zombie.h }
            if line_rect_overlap(line, rect) then
                table.insert(can_hit, zombie)
            end
        end
    end

    if #can_hit == 0 then return nil end

    local closest_index = 1
    local closest_distance = util.vec_dist({ x = x1, y = y1 },
        { x = can_hit[1].x + ZOMBIE_W_ADJUST + 3, y = can_hit[1].y + ZOMBIE_H_ADJUST + 3 })
    -- get the closest one out of the hits
    for i, zombie in pairs(can_hit) do
        local distance = util.vec_dist({ x = x1, y = y1 },
            { x = zombie.x + ZOMBIE_W_ADJUST + 3, y = zombie.y + ZOMBIE_H_ADJUST + 3 })
        if distance < closest_distance then
            closest_distance = distance
            closest_index = i
        end
    end

    return can_hit[closest_index], closest_distance
end

local function shoot()
    local vec = util.vec_from_angle(Mouse_Angle, 7)
    local adjusted_spread = Weapon.spread * 0.01
    local adjusted_x, adjusted_y = Player.x + 8, Player.y + 10

    Ammo -= 1

    for i = 1, Weapon.count do
        local spread = math.random() * adjusted_spread - adjusted_spread / 2

        -- calculates the hitbox of the bullet
        local start_x, start_y = adjusted_x + vec.x, adjusted_y + vec.y
        local spread_vec = util.vec_from_angle(Mouse_Angle + spread, 500)
        local end_x, end_y = start_x + spread_vec.x, start_y + spread_vec.y

        local zombie, distance = hit_zombie(start_x, start_y, end_x, end_y)
        if zombie then
            zombie.health -= Weapon.damage

            -- knockback
            local scaled_damage = Weapon.damage / 10
            local kb_x = math.floor(vec.x * scaled_damage)
            local kb_y = math.floor(vec.y * scaled_damage)
            apply_knockback_zombie(zombie, kb_x, kb_y)
            dandelion.zombie_spray(start_x + math.cos(Mouse_Angle + spread) * distance,
                start_y + math.sin(Mouse_Angle + spread) * distance, { spray_x = vec.x, spray_y = vec.y })

            dandelion.hitscan_bullet(start_x, start_y,
                { ["config"] = { length = distance, rotation = Mouse_Angle + spread } })
        else
            dandelion.hitscan_bullet(start_x, start_y,
                { ["config"] = { length = 1000, rotation = Mouse_Angle + spread } })
        end
        dandelion.small_smoke(start_x, start_y)
    end

    dandelion[BULLETS[Weapon.bullet].particle](adjusted_x, adjusted_y, { flip = Player.flip and 1 or -1 })
    conditional_screen_shake(0.1, Weapon.recoil)
    Fire_Cooldown = usagi.elapsed
end

local function blocked_by_wall(x, y, w, h)
    local left_edge = x
    local right_edge = x + w

    if y + h < WALL_START then
        return nil
    end

    -- convert edges to Walls index
    -- local l_index = math.floor(left_edge, 0,usagi.GAME_W, 1,20))
    -- local r_index = math.floor(util.remap(right_edge, 0,usagi.GAME_W, 1,21))
    local l_index = util.clamp(math.floor(left_edge / 16) + 1, 1, 20)
    local r_index = util.clamp(math.floor(right_edge / 16) + 1, 1, 20)



    if Walls[l_index] > 0 and Walls[r_index] > 0 then
        return l_index, r_index
    end

    if Walls[l_index] > 0 then
        return l_index
    end

    if Walls[r_index] > 0 then
        return r_index
    end

    return nil
end

local function game_over_sequence()
    local over_for = usagi.elapsed - Game_Over

    if over_for > 2 and Game_Over_Phase == 0 then
        conditional_screen_shake(0.5, 1)
        dandelion.game_over(32, 16)
        Game_Over_Phase = 1
    end

    if over_for > 3 and Game_Over_Phase == 1 then
        conditional_screen_shake(0.5, 0.5)
        dandelion.stats_text(32, 48, { print = "Zombies Killed: " .. Zombies_Killed })
        Game_Over_Phase = 2
    end
    if over_for > 3.5 and Game_Over_Phase == 2 then
        conditional_screen_shake(0.5, 0.5)
        dandelion.stats_text(32, 60, { print = "Money Made: " .. Money_Made })
        Game_Over_Phase = 3
    end
    if over_for > 4 and Game_Over_Phase == 3 then
        conditional_screen_shake(0.5, 0.5)
        dandelion.stats_text(32, 72, { print = "Days Survived: " .. Day - 1 })
        Game_Over_Phase = 4
    end

    if over_for > 5 and Game_Over_Phase == 4 then
        conditional_screen_shake(0.5, 0.75)
        dandelion.stats_text(32, 96, { print = "Press [SPACE] to restart." })
        Game_Over_Phase = 5
    end

    if input.key_pressed(input.KEY_SPACE) then
        reset()
    end
end

local function check_player_dead()
    if Player.health <= 0 then
        dandelion.player_die(Player.x + 8, Player.y + 6)
        conditional_screen_shake(2, 1)
        Game_Over = usagi.elapsed
    end
end

local function damage_player(damage)
    Player.last_health = Player.health
    Player.health -= damage
    Player.last_hit = usagi.elapsed
    conditional_screen_shake(0.25, damage * 0.1)
    local hp_percent = 64 * Player.health / PLAYER_HEALTH
    dandelion.health_bar_hit(4 + hp_percent, 168, { length = 4 * (Player.last_health - Player.health) })
    dandelion.player_hit(Player.x + 8, Player.y)
    conditional_screen_shake(0.25, damage * 0.25)
    check_player_dead()
end

local function change_money(amount)
    if amount == 0 then
        return
    end
    local length = math.floor(math.log(math.abs(amount), 10)) * 6
    if amount > 0 then
        Money_Made += amount
        dandelion.money_up(310, 149 - math.max(0, Drawer_Height - 12), { amount = amount, length = length })
    else
        dandelion.money_down(310, 149 - math.max(0, Drawer_Height - 12), { amount = math.abs(amount), length = length })
    end
    Money += amount
end


local function get_nearest_in_range(range)
    local can_hit = {}
    local closest_distance = 9999
    local closest_index = 0
    for _, zombie in pairs(Zombies) do
        if zombie.y <= WALL_START - 40 and not zombie.on_wall then -- zombies past the wall cannot be shot
            local rect = { x = zombie.x + ZOMBIE_W_ADJUST, y = zombie.y + ZOMBIE_H_ADJUST, w = zombie.w, h = zombie.h }
            if util.circ_rect_overlap(range, rect) then
                table.insert(can_hit, zombie)
                local distance = util.vec_dist({ x = range.x, y = range.y },
                    { x = zombie.x + ZOMBIE_W_ADJUST + 3, y = zombie.y + ZOMBIE_H_ADJUST + 3 })
                if distance < closest_distance then
                    closest_distance = distance
                    closest_index = #can_hit
                end
            end
        end
    end

    if #can_hit == 0 then return nil end

    return can_hit[closest_index], closest_distance
end

local function get_all_in_range(range)
    local can_hit = {}
    for _, zombie in pairs(Zombies) do
        if zombie.y <= WALL_START - 40 and not zombie.on_wall then -- zombies past the wall cannot be shot
            local rect = { x = zombie.x + ZOMBIE_W_ADJUST, y = zombie.y + ZOMBIE_H_ADJUST, w = zombie.w, h = zombie.h }
            if util.circ_rect_overlap(range, rect) then
                table.insert(can_hit, zombie)
            end
        end
    end

    if #can_hit == 0 then return nil end

    return can_hit
end

local function boomer_explode(zombie)
    zombie.health = 0
    conditional_screen_shake(1, 2)
    dandelion.boomer_explode(zombie.x + ZOMBIE_W_ADJUST, zombie.y + ZOMBIE_H_ADJUST)
    local circle = { x = zombie.x + ZOMBIE_W_ADJUST, y = zombie.y + ZOMBIE_H_ADJUST, r = 24 }
    local targets = get_all_in_range(circle)
    if zombie.on_wall and util.circ_rect_overlap(circle, { x = Player.x, y = Player.y, w = ZOMBIE_W_ADJUST, h = ZOMBIE_H_ADJUST }) then
        damage_player(50)
    end
    if targets then
        for _, target in pairs(targets) do
            local dx, dy = target.x + ZOMBIE_W_ADJUST - zombie.x, target.y + ZOMBIE_H_ADJUST - zombie.y
            local h = util.vec_dist({ x = 0, y = 0 }, { x = dx, y = dy })
            local theta = math.asin(dy / h)
            local angle = dx > 0 and theta or (math.pi - theta)
            local distance = util.vec_dist({ x = zombie.x, y = zombie.y },
                { x = target.x + ZOMBIE_W_ADJUST, y = target.y + ZOMBIE_H_ADJUST })
            local damage = 5 + 15 - distance / 2
            local vec = util.vec_from_angle(angle, math.random() * damage / 2 + damage / 2)
            if string.match(target.type, "boomer") and target.health > 0 then
                boomer_explode(target)
            end
            target.health -= damage
            apply_knockback_zombie(target, vec.x, vec.y)
        end
    end
end

local function do_zombies()
    for i = #Zombies, 1, -1 do
        local zombie = Zombies[i]

        if zombie.health <= 0 then
            -- zombie died
            dandelion.zombie_die(zombie.x + ZOMBIE_W_ADJUST + 4, zombie.y + ZOMBIE_H_ADJUST)
            Zombies_Killed += 1
            change_money(zombie.money)
            table.remove(Zombies, i)

            if string.match(zombie.type, "conjoined") then
                for _ = 1, zombie.count do
                    dandelion.zombie_die(zombie.x + ZOMBIE_W_ADJUST + 4, zombie.y + ZOMBIE_H_ADJUST - 4)
                    dandelion.zombie_die(zombie.x + ZOMBIE_W_ADJUST + 4, zombie.y + ZOMBIE_H_ADJUST + 4)
                    local x = zombie.x - ZOMBIE_W_ADJUST + 4 + math.random() * 8 - 4
                    local y = zombie.y - ZOMBIE_H_ADJUST + math.random() * 8 - 4
                    spawn_zombie("shambler_1", x, y, zombie.on_wall)
                end
            elseif string.match(zombie.type, "boomer") then
                boomer_explode(zombie)
            end
        else
            local elapsed = usagi.elapsed

            if zombie.kb_x ~= 0 then -- weapon stun
                local direction = zombie.kb_x > 0 and 1 or -1
                local amount = math.sqrt(math.abs(zombie.kb_x))
                zombie.kb_x = util.approach(zombie.kb_x, 0, amount)
                zombie.x = util.clamp(zombie.x + direction * amount, -6, usagi.GAME_W - ZOMBIE_W_ADJUST * 2)
                zombie.last_move = elapsed - zombie.move_delay * 0.5
            end
            if zombie.kb_y ~= 0 then -- weapon stun
                local direction = zombie.kb_y > 0 and 1 or -1
                local amount = math.sqrt(math.abs(zombie.kb_y))
                zombie.kb_y = util.approach(zombie.kb_y, 0, amount)
                zombie.y += amount * direction
                zombie.last_move = elapsed - zombie.move_delay * 0.5
            end

            if elapsed - zombie.last_move > zombie.move_delay then -- normal walking
                if zombie.on_wall then
                    local diff = Player.x - zombie.x
                    if diff > 0 then
                        zombie.flip = false
                        zombie.x += ZOMBIE_SPEED
                    else
                        zombie.flip = true
                        zombie.x -= ZOMBIE_SPEED
                    end

                    -- player damage
                    if util.rect_overlap(
                            { x = zombie.x, y = zombie.y, w = ZOMBIE_W_ADJUST, h = ZOMBIE_H_ADJUST },
                            { x = Player.x, y = Player.y, w = ZOMBIE_W_ADJUST, h = ZOMBIE_H_ADJUST }
                        ) and elapsed - Player.last_hit > 0.25 then
                        Player.kb = diff > 0 and (zombie.damage * 2) or (-2 * zombie.damage)
                        damage_player(zombie.damage)
                        if string.match(zombie.type, "boomer") then
                            boomer_explode(zombie)
                        end
                    end
                    zombie.last_move = elapsed - zombie.move_delay / 2
                else
                    local wall1, wall2 = blocked_by_wall(zombie.x + ZOMBIE_W_ADJUST, zombie.y + ZOMBIE_H_ADJUST,
                        ZOMBIE_W_ADJUST, ZOMBIE_H_ADJUST)
                    if wall1 or wall2 and string.match(zombie.type, "boomer") then
                        boomer_explode(zombie)
                        if wall1 then
                            Walls[wall1] = 0
                        end
                        if wall2 then
                            Walls[wall2] = 0
                        end
                    end
                    if wall1 then
                        Walls[wall1] = math.max(0, Walls[wall1] - zombie.damage)
                        dandelion.hit_wall((wall1 - 1) * 16 + 8, 140)
                    end
                    if wall2 and wall1 ~= wall2 then
                        Walls[wall2] = math.max(0, Walls[wall2] - zombie.damage)
                        dandelion.hit_wall((wall2 - 1) * 16 + 8, 140)
                    end
                    if not wall1 and not wall2 then
                        zombie.y += ZOMBIE_SPEED
                        if zombie.y > usagi.GAME_H then
                            zombie.on_wall = true
                            zombie.y = 134 + math.random() * 4 - 2
                            zombie.x = zombie.flip and (usagi.GAME_W + ZOMBIE_W_ADJUST * 3) or (ZOMBIE_W_ADJUST * -2)
                        end
                    else
                        conditional_screen_shake(0.25, zombie.damage * 0.025)
                    end
                    zombie.last_move = elapsed
                end
                zombie.moved = true
                zombie.current_frame = util.wrap(zombie.current_frame + 1, 0, 2)
            end
        end
    end
end

local function total_undead_weight()
    local to_return = 0
    for _, v in pairs(Discovered_Mutations) do
        to_return += ZOMBIES[v].weight
    end
    return to_return
end

local function get_random_undead(total)
    local roll = math.random(1, total)
    local cumulative = 0

    for _, type in pairs(Discovered_Mutations) do
        local weight = ZOMBIES[type].weight
        cumulative += weight
        if roll < cumulative then
            return type
        end
    end
    return "shambler_1"
end

local function start_next_night()
    local budget = 3 * Day + (Day + 3) ^ 2 + math.random(1, Day * 2)

    local night_length = util.remap(Day, 1, 31, 30, 120)

    -- duration between waves during the night
    -- each wave will try to spawn 5 weight worth of undead
    local spacing = night_length / (budget / 5)

    local total_weight = total_undead_weight()

    for i = 1, night_length, spacing do
        local type = get_random_undead(total_weight)
        local cost = ZOMBIES[type].cost
        local count = util.round(5 / cost)
        local wave_spawn = {
            time = i,
            count = count,
            type = type,
            spread = {
                x = ZOMBIES[type].spread_x,
                y = ZOMBIES[type].spread_y
            }
        }
        table.insert(Current_Wave, wave_spawn)
    end

    Is_Night = true
    Choice_Progression = 0
    Transition_Started = usagi.elapsed
end

local function next_day()
    Is_Night = false
    dandelion.ClearEmitters()
    Weather = "clear"
    if math.random() > 0.75 then
        Weather = "rain"
        dandelion.rain_emitter(usagi.GAME_W / 2, usagi.GAME_H / 2)
    end
    Transition_Started = usagi.elapsed

    if (Day - 3) % 4 == 0 then
        -- choose upgrade
    else
        if Next_Is_Unlock then
            Choice_1 = UNLOCKS[table.remove(Potential_Unlocks, 1)]
            Choice_2 = UNLOCKS[table.remove(Potential_Unlocks, 1)]
            Choice_Type = "unlock"
        else
            local f = table.remove(Potential_Mutations, 1)
            local s = table.remove(Potential_Mutations, 1)
            Choice_1 = ZOMBIES[f]
            Choice_1.id = f
            Choice_2 = ZOMBIES[s]
            Choice_2.id = s
            Choice_Type = "mutation"
        end
        Next_Is_Unlock = not Next_Is_Unlock
    end
    Day += 1
end

local function do_waves()
    if #Current_Wave == 0 and #Zombies == 0 then
        next_day()
        return
    end

    if #Current_Wave == 0 then return end

    local next_spawn = Current_Wave[1]
    if usagi.elapsed - Transition_Started > next_spawn.time then
        for i = 1, next_spawn.count do
            local x = math.random(150 - next_spawn.spread.x / 2, 155 + next_spawn.spread.x / 2)
            local y = -1 * (math.random(0, next_spawn.spread.y) + 20)
            spawn_zombie(next_spawn.type, x, y, false)
        end
        table.remove(Current_Wave, 1)
    end
end

local function next_upgrade(id)
    local len = string.len(id)
    local last = string.sub(id, len)
    local level = tonumber(last)
    if level then
        level += 1
        id = string.sub(id, 1, len - 1) .. level
        if Discovered_Upgrades[id] then
            return id
        end
    end
    return nil
end

local function fill_drawer_items()
    Drawer_Items = {}
    if Drawer_Type == "turret" then
        local selected = Turrets[Selected_Turret]

        -- empty turret slot
        if not selected then
            for _, name in pairs(Discovered_Turrets) do
                table.insert(Drawer_Items, TURRETS[name])
            end
        else -- check for upgrades
            local id = next_upgrade(selected.id)
            if id then
                table.insert(Drawer_Items, TURRETS[id])
            end
        end
    elseif Drawer_Type == "weapon" then
        for id, _ in pairs(Discovered_Weapons) do
            table.insert(Drawer_Items, WEAPONS[id])
        end
    elseif Drawer_Type == "grenade" then
        for id, _ in pairs(Discovered_Grenades) do
            table.insert(Drawer_Items, GRENADES[id])
        end
    end
end

local function do_turrets()
    for i, turret in pairs(Turrets) do
        if not turret then goto continue end
        if usagi.elapsed - turret.cooldown < turret.fire_rate then goto continue end

        local range = { x = i * 20 - 10, y = 126, r = turret.range }
        local z = get_nearest_in_range(range)

        if not z then goto continue end

        local dx, dy = z.x + ZOMBIE_W_ADJUST + 2 - range.x, z.y + ZOMBIE_H_ADJUST + 2 - range.y
        local h = util.vec_dist({ x = 0, y = 0 }, { x = dx, y = dy })
        local theta = math.asin(dy / h)
        local angle = dx > 0 and theta or (math.pi - theta)
        turret.angle = angle

        local vec = util.vec_from_angle(angle, 24)
        local adjusted_spread = turret.spread * 0.01

        for j = 1, turret.count do
            local spread = math.random() * adjusted_spread - adjusted_spread / 2

            -- calculates the hitbox of the bullet
            local start_x, start_y = range.x + vec.x, range.y + vec.y
            local spread_vec = util.vec_from_angle(angle + spread, 500)
            local end_x, end_y = start_x + spread_vec.x, start_y + spread_vec.y

            local zombie, distance = hit_zombie(start_x, start_y, end_x, end_y)
            if zombie then
                if turret.bullet == "rifle" then
                    zombie.health -= turret.damage

                    -- knockback
                    local scaled_damage = turret.damage / 10
                    local kb_x = math.floor(vec.x * scaled_damage)
                    local kb_y = math.floor(vec.y * scaled_damage)
                    apply_knockback_zombie(zombie, kb_x, kb_y)
                end

                dandelion.zombie_spray(start_x + math.cos(angle + spread) * distance,
                    start_y + math.sin(angle + spread) * distance, { spray_x = vec.x / 4, spray_y = vec.y / 4 })
                dandelion.hitscan_bullet(start_x, start_y,
                    { ["config"] = { length = distance, rotation = angle + spread, thickness = 1 } })
            else
                dandelion.hitscan_bullet(start_x, start_y,
                    { ["config"] = { length = 1000, rotation = angle + spread, thickness = 1 } })
            end
            dandelion.small_smoke(start_x, start_y)
        end

        dandelion[BULLETS[turret.bullet].particle](range.x, range.y, { flip = Player.flip and 1 or -1 })
        -- conditional_screen_shake(0.1, turret.recoil * 0.5)
        turret.cooldown = usagi.elapsed
        ::continue::
    end
end

local function do_grenades()
    for i = #Grenades, 1, -1 do
        local grenade = Grenades[i]
        grenade.age = usagi.elapsed - grenade.born
        local duration = grenade.duration
        local t = grenade.age / duration

        grenade.cx = util.lerp(grenade.x, grenade.dx, t)
        grenade.cy = util.lerp(grenade.y, grenade.dy, t)
        grenade.scale = 0.2 + 0.8 * (1 - math.abs(2 * t - 1) ^ 3)

        if grenade.age > duration then
            table.remove(Grenades, i)
            if grenade.id == "frag_grenade" then
                conditional_screen_shake(1, 2)
                dandelion.frag_grenade(grenade.dx, grenade.dy)
                local targets = get_all_in_range({ x = grenade.dx, y = grenade.dy, r = 32 })
                if targets then
                    for _, zombie in pairs(targets) do
                        local dx, dy = zombie.x + ZOMBIE_W_ADJUST - grenade.dx, zombie.y + ZOMBIE_H_ADJUST - grenade.dy
                        local h = util.vec_dist({ x = 0, y = 0 }, { x = dx, y = dy })
                        local theta = math.asin(dy / h)
                        local angle = dx > 0 and theta or (math.pi - theta)
                        local distance = util.vec_dist({ x = grenade.dx, y = grenade.dy },
                            { x = zombie.x + ZOMBIE_W_ADJUST, y = zombie.y + ZOMBIE_H_ADJUST })
                        local damage = 5 + 48 - distance
                        local vec = util.vec_from_angle(angle, math.random() * damage / 2 + damage / 2)
                        zombie.health -= damage
                        apply_knockback_zombie(zombie, vec.x, vec.y)
                    end
                end
            end
            -- print("explode")
        end
    end
end

function _update(dt)
    if Game_Over then
        game_over_sequence()
        return
    end

    if Reloading and usagi.elapsed - Reload_Start > Weapon.reload then
        Reloading = false
        Ammo = Weapon.ammo
    end

    if Is_Night then
        do_waves()
        do_turrets()
        do_zombies()
    end
    do_grenades()

    local mx, my = input.mouse()
    local dx, dy = mx - Player.x - 8, my - Player.y - 11
    local h = util.vec_dist({ x = 0, y = 0 }, { x = dx, y = dy })
    local theta = math.asin(dy / h)
    Mouse_Angle = dx > 0 and theta or (math.pi - theta)
    Mouse_Distance = h
    GunAngle = dx > 0 and theta or (math.pi - theta)
    Player.flip = dx < 0 and true or false

    if Player.kb ~= 0 then
        local amount = math.sqrt(math.abs(Player.kb))
        Player.x += amount * (Player.kb > 0 and 1 or -1)
        Player.kb = util.approach(Player.kb, 0, amount)
    end

    if input.key_held(input.KEY_H) then
        spawn_zombie("shambler_1", 60, 0)
    end

    if input.key_pressed(input.KEY_C) then
        change_money(250)
    end

    if input.key_pressed(input.KEY_U) then
        Zombies = {}
        Current_Wave = {}
    end

    local should_move = false
    if input.key_held(input.KEY_A) and Player.kb == 0 then
        Player.x = util.clamp(Player.x - PLAYER_SPEED * dt, 0, 309)
        if Player.moving == false then
            Player.frame_time = 0
        end
        should_move = true
    end

    if input.key_held(input.KEY_D) and Player.kb == 0 then
        Player.x = util.clamp(Player.x + PLAYER_SPEED * dt, 0, 309)
        if Player.moving == false then
            Player.frame_time = 0
        end
        should_move = true
    end

    Player.moving = should_move

    if input.key_pressed(input.KEY_G) and #Grenade_Inventory > 0 then
        local model = table.remove(Grenade_Inventory)
        local grenade = {}
        for k, v in pairs(model) do
            grenade[k] = v
        end
        grenade.born = usagi.elapsed
        grenade.age = 0
        grenade.x = Player.x + 5
        grenade.y = Player.y + 7
        grenade.cx = Player.x + 5
        grenade.cy = Player.y + 7
        grenade.dx = mx
        grenade.dy = my
        grenade.duration = h / 200
        grenade.scale = 0
        grenade.random = math.random()
        table.insert(Grenades, grenade)
    end

    if Is_Night then
        if input.mouse_held(input.MOUSE_LEFT) then
            if usagi.elapsed - Fire_Cooldown > Weapon.fire_rate then
                if Ammo > 0 then
                    shoot()
                end
                if Ammo < 1 and not Reloading then
                    Reloading = true
                    Reload_Start = usagi.elapsed
                end
            end
        end
    else
        if Choice_1 and Choice_2 then
            if util.circ_rect_overlap({ x = mx, y = my, r = 1 }, { x = 8, y = 16, w = 144, h = 100 }) then
                Highlighted_Choice = 1
            elseif util.circ_rect_overlap({ x = mx, y = my, r = 1 }, { x = 172, y = 16, w = 144, h = 100 }) then
                Highlighted_Choice = 2
            else
                Highlighted_Choice = nil
            end

            if input.mouse_pressed(input.MOUSE_LEFT) then
                if Highlighted_Choice and Choice_Progression > 2 then
                    local choice = Highlighted_Choice == 1 and Choice_1 or Choice_2
                    local discarded = Highlighted_Choice == 1 and Choice_2 or Choice_1

                    if choice.class == "Turret" then
                        table.insert(Discovered_Turrets, choice.id)
                    end
                    if choice.class == "Upgrade" then
                        Discovered_Upgrades[choice.id] = true
                    end
                    if choice.class == "Weapon" then
                        Discovered_Weapons[choice.id] = false
                    end
                    if choice.class == "Grenade" then
                        Discovered_Grenades[choice.id] = false
                    end
                    if Choice_Type == "mutation" then
                        -- discarded goes to back of line
                        table.insert(Potential_Mutations, discarded.id)
                        table.insert(Discovered_Mutations, choice.id)
                        local previous = nil
                        for i, v in pairs(Discovered_Mutations) do
                            if v == choice.previous then
                                previous = i
                            end
                        end
                        if previous then
                            table.remove(Discovered_Mutations, previous)
                        end
                        if choice.next then
                            table.insert(Potential_Mutations, math.random(1, math.floor(#Potential_Mutations / 2) or 1),
                                choice.next)
                        end
                        print(#Potential_Mutations)
                    else
                        -- discarded goes to back of line
                        table.insert(Potential_Unlocks, discarded.id)
                    end
                    -- next preferred upgrade is put somewhere in the front half
                    if Choice_Type ~= "mutation" and choice.next then
                        table.insert(Potential_Unlocks, math.random(1, math.floor(#Potential_Unlocks / 2) or 1),
                            choice.next)
                    end
                    -- print(usagi.to_json(Potential_Unlocks))
                    Choice_1 = nil
                    Choice_2 = nil
                    Highlighted_Choice = 0
                    Choice_Type = nil
                end
            end
        else
            if input.key_pressed(input.KEY_B) then
                if Drawer then
                    Drawer = false
                    Selected_Turret = nil
                else
                    Drawer = true
                    Drawer_Type = "weapon"
                    fill_drawer_items()
                end
            end
            if my > 116 and my < 136 then
                Highlighted_Turret = math.floor(mx / 20 + 1)
            else
                Highlighted_Turret = nil
            end

            Highlighted_Drawer_Item = nil
            Highlighted_Tab = nil
            if Drawer then
                if my >= usagi.GAME_H - 32 and my <= usagi.GAME_H - 4 and mx >= 16 and mx <= usagi.GAME_W - 16 then
                    local index = math.floor((mx - 16) / 32 + 1)
                    if index <= #Drawer_Items then
                        Highlighted_Drawer_Item = index
                    end
                end

                if util.circ_rect_overlap({ x = mx, y = my, r = 1 }, { x = 18, y = 137, w = 50, h = 10 }) then
                    Highlighted_Tab = "weapon"
                elseif util.circ_rect_overlap({ x = mx, y = my, r = 1 }, { x = 130, y = 137, w = 50, h = 10 }) then
                    Highlighted_Tab = "turret"
                elseif util.circ_rect_overlap({ x = mx, y = my, r = 1 }, { x = 246, y = 137, w = 60, h = 10 }) then
                    Highlighted_Tab = "grenade"
                end
            end

            if input.mouse_pressed(input.MOUSE_LEFT) then
                if my < 120 then
                    Drawer = false
                    Selected_Turret = nil
                elseif Highlighted_Turret ~= nil then
                    Selected_Turret = Highlighted_Turret
                    Drawer = true
                    Drawer_Type = "turret"
                    fill_drawer_items()
                elseif Highlighted_Drawer_Item ~= nil then
                    local item = Drawer_Items[Highlighted_Drawer_Item]
                    if Drawer_Type == "turret" then
                        if item.cost > Money then
                            conditional_screen_shake(0.25, 0.25)
                        else
                            change_money(item.cost * -1)
                            Turrets[Selected_Turret] = {}
                            Turrets[Selected_Turret].cooldown = 0
                            Turrets[Selected_Turret].angle = -0.5 * math.pi
                            for k, v in pairs(item) do
                                Turrets[Selected_Turret][k] = v
                            end
                            dandelion.construction((Selected_Turret - 1) * 20 + 10, 128)
                            conditional_screen_shake(0.25, 0.75)
                            fill_drawer_items()
                        end
                    elseif Drawer_Type == "weapon" then
                        if item.id == Weapon.id or (item.cost > Money and not Discovered_Weapons[item.id]) then
                            conditional_screen_shake(0.25, 0.25)
                        else
                            if not Discovered_Weapons[item.id] then
                                change_money(item.cost * -1)
                            end
                            Weapon = WEAPONS[item.id]
                            Ammo = Weapon.ammo
                            Discovered_Weapons[item.id] = true
                        end
                    elseif Drawer_Type == "grenade" then
                        if #Grenade_Inventory >= Grenade_Slots or item.cost > Money then
                            conditional_screen_shake(0.25, 0.25)
                        else
                            change_money(item.cost * -1)
                            table.insert(Grenade_Inventory, item)
                        end
                    end
                elseif Highlighted_Tab then
                    Drawer_Type = Highlighted_Tab
                    if Highlighted_Tab == "turret" then
                        Selected_Turret = 1
                    else
                        Selected_Turret = nil
                    end
                    fill_drawer_items()
                end
            end
        end
    end

    if input.key_pressed(input.KEY_SPACE) and Is_Night == false and not Choice_1 and Player.x < 10 then
        Drawer = false
        Selected_Turret = nil
        Highlighted_Turret = nil
        Highlighted_Drawer_Item = nil
        start_next_night()
    end

    if input.key_pressed(input.KEY_K) then
        Screen_Shake = not Screen_Shake
        local text = Screen_Shake and "Screen Shake ENABLED" or "Screen Shake DISABLED"
        dandelion.debug_text(mx, my, { print = text })
    end
end

local function draw_zombies()
    for i, zombie in pairs(Zombies) do
        if zombie.on_wall then
            table.insert(WallZombies, zombie)
        elseif zombie.moved then
            gfx.sspr_ex(zombie.spr_x + zombie.variant * H_SIZE, zombie.spr_y + zombie.current_frame * H_SIZE, H_SIZE,
                H_SIZE, zombie.x, zombie.y, H_SIZE, H_SIZE,
                zombie.flip,
                false, 0, gfx.COLOR_TRUE_WHITE, 1)
        end
    end
end

local function draw_wall_zombies()
    for i = #WallZombies, 1, -1 do
        local zombie = WallZombies[i]
        if zombie.moved then
            gfx.sspr_ex(zombie.spr_x + zombie.variant * H_SIZE, zombie.spr_y + zombie.current_frame * H_SIZE, H_SIZE,
                H_SIZE, zombie.x, zombie.y, H_SIZE, H_SIZE,
                zombie.flip,
                false, 0, gfx.COLOR_TRUE_WHITE, 1)
        end
        table.remove(WallZombies, i)
    end
end

local function draw_player()
    -- adjust to accommodate player skin
    local offset = Player_Skin * H_SIZE

    -- used for arm recoil
    local vec = util.vec_from_angle(Mouse_Angle, 1)
    local m = usagi.elapsed - Fire_Cooldown < (0.025 + Weapon.recoil / 16) and -1 * math.max(Weapon.recoil, 1) or 0

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
        Player.flip, Mouse_Angle, gfx.COLOR_TRUE_WHITE, 1)

    -- gun
    gfx.sspr_ex(Weapon.x, Weapon.y, H_SIZE, H_SIZE, Player.x + m * vec.x, Player.y + 2 + m * vec.y, H_SIZE, H_SIZE,
        false,
        Player.flip, GunAngle, gfx.COLOR_TRUE_WHITE, 1)
end

local function draw_crosshair()
    local mx, my = input.mouse()

    local adjusted_spread = Is_Night and ((Mouse_Distance / 150) * Weapon.spread / 2) or 0

    local elapsed = usagi.elapsed - Fire_Cooldown

    if elapsed < Weapon.fire_rate then
        local m = (1 - elapsed / Weapon.fire_rate) ^ 2
        adjusted_spread += m * 3
    end

    gfx.line(mx + adjusted_spread + 1, my, mx + 1.5 * adjusted_spread + 3, my, gfx.COLOR_TRUE_WHITE)
    gfx.line(mx - (adjusted_spread + 2), my, mx - (1.5 * adjusted_spread + 4), my, gfx.COLOR_TRUE_WHITE)
    gfx.line(mx, my + (adjusted_spread + 2), mx, my + (1.5 * adjusted_spread + 4), gfx.COLOR_TRUE_WHITE)
    gfx.line(mx, my - (adjusted_spread + 1), mx, my - (1.5 * adjusted_spread + 3), gfx.COLOR_TRUE_WHITE)
end

local function bold_text_with_shadow(text, x, y, color, shadow_color)
    gfx.text_ex(text, x, y + 2, 2, 0, shadow_color, 1)
    gfx.text_ex(text, x + 1, y + 2, 2, 0, shadow_color, 1)
    gfx.text_ex(text, x, y, 2, 0, color, 1)
    gfx.text_ex(text, x + 1, y, 2, 0, color, 1)
end

local function text_with_shadow(text, x, y, color, shadow_color)
    gfx.text(text, x, y + 1, shadow_color)
    gfx.text(text, x, y, color)
end

local function draw_hud()
    -- Ammo bar
    gfx.rect_fill(4, 157, Weapon.ammo * (BULLETS[Weapon.bullet].spr_w + 1) + 3, 10, gfx.COLOR_BLACK)
    gfx.rect_fill(4, 156, Weapon.ammo * (BULLETS[Weapon.bullet].spr_w + 1) + 3, 10, gfx.COLOR_DARK_GRAY)
    local bullet = BULLETS[Weapon.bullet]
    if Reloading then
        text_with_shadow("Reloading...", Weapon.ammo * (bullet.spr_w + 1) + 9, 154, gfx.COLOR_WHITE, gfx
            .COLOR_DARK_GRAY)
    end
    for i = Ammo + 1, Weapon.ammo do
        gfx.sspr(bullet.spr_x, bullet.spr_y + bullet.spr_h, bullet.spr_w, bullet.spr_h, 6 + (i - 1) * (bullet.spr_w + 1),
            158)
    end
    for i = 1, Ammo do
        gfx.sspr(bullet.spr_x, bullet.spr_y, bullet.spr_w, bullet.spr_h, 6 + (i - 1) * (bullet.spr_w + 1), 158)
    end

    -- Health bar
    local hp_percent = Player.health / PLAYER_HEALTH
    local last_hp_percent = 64 * (Player.last_health - Player.health) / PLAYER_HEALTH
    -- local hp_color = usagi.elapsed - Player.last_hit > 0.125 and gfx.COLOR_RED or gfx.COLOR_WHITE
    local max = 4 + 3 * PLAYER_HEALTH
    gfx.rect_fill(4, 168, max, 10, gfx.COLOR_DARK_PURPLE)
    gfx.rect_fill(4, 168, hp_percent * max, 9, gfx.COLOR_RED)
    if usagi.elapsed - Player.last_hit < 0.25 then
        gfx.rect_fill(4 + hp_percent * max, 168, last_hp_percent, 9,
            gfx.COLOR_WHITE)
    end

    -- Money and days
    local money = "$" .. Money
    if not Is_Night and not Choice_1 then
        money = "Shop [B] " .. money
    end
    local money_size = #money * 6
    text_with_shadow(money, 316 - money_size, 154 - math.max(0, Drawer_Height - 12), gfx.COLOR_YELLOW, gfx.COLOR_BROWN)
    local day_night = Is_Night and "Night " or "Day "
    local counter = day_night .. Day .. "/31"
    local counter_size = #counter * 6
    text_with_shadow(counter, 316 - counter_size, 165, gfx.COLOR_WHITE, gfx.COLOR_DARK_GRAY)
end

local function draw_turrets()
    for i, turret in pairs(Turrets) do
        if turret then
            local tint = Selected_Turret == i and gfx.COLOR_YELLOW or gfx.COLOR_TRUE_WHITE

            local recoil = util.vec_from_angle(turret.angle, 1)
            local angle = turret.angle + 0.5 * math.pi
            local m = (usagi.elapsed - turret.cooldown < 0.05 and -1 or 0) * turret.recoil

            -- barrel
            local height = 118
            gfx.sspr_ex(turret.x, turret.y - 32, 16, 48, (i - 1) * 20 + 2 + m * recoil.x, height - 15 + m * recoil.y, 16,
                48,
                false, false,
                angle, tint, 1)
            -- body
            gfx.sspr_ex(turret.x, turret.y + 16, 16, 16, (i - 1) * 20 + 2, height, 16, 16, false, false, 0, tint, 1)

            if not Is_Night and not Choice_1 then
                local id = next_upgrade(turret.id)
                if id and TURRETS[id].cost <= Money then
                    text_with_shadow("!", (i - 1) * 20 + 2, 112, gfx.COLOR_YELLOW, gfx.COLOR_BROWN)
                end
            end
        end
    end
end

local function draw_turret_outlines()
    local height = 118
    for i, turret in pairs(Turrets) do
        if i == Highlighted_Turret then
            gfx.rect((Highlighted_Turret - 1) * 20, height - 2, 20, 20, gfx.COLOR_TRUE_WHITE)
        end
        local tint = Selected_Turret == i and gfx.COLOR_YELLOW or gfx.COLOR_LIGHT_GRAY
        if not turret then
            gfx.spr_ex(1, (i - 1) * 20 + 2, height, false, false, 0, tint, 1)
        end
    end
end

local function draw_rampart()
    for i = 1, #Walls do
        local offset = Walls[i] > 0 and 0 or 1
        gfx.sspr(offset * H_SIZE, 208, H_SIZE, H_SIZE, (i - 1) * H_SIZE, 135)
    end
end

local function draw_walls()
    for i = 1, #Walls do
        local offset = util.round(6 - (Walls[i] + 11) / 20)
        if Walls[i] == 0 then
            offset = 6
        end
        gfx.sspr(offset * H_SIZE, 224, H_SIZE, H_SIZE, (i - 1) * H_SIZE, 148)
        gfx.sspr(offset * H_SIZE, 240, H_SIZE, H_SIZE, (i - 1) * H_SIZE, 164)
    end
end

local function draw_stats(item)
    bold_text_with_shadow(item.name, 16, 16, gfx.COLOR_RED, gfx.COLOR_DARK_PURPLE)

    local desc_color = gfx.COLOR_TRUE_WHITE
    local shadow_color = gfx.COLOR_INDIGO
    text_with_shadow(item.description, 16, 40, desc_color, shadow_color)
    text_with_shadow("Damage ", 16, 56, desc_color, shadow_color)


    local stat_offset = 72
    local y_offset = 60
    for d = 1, item.damage do
        gfx.rect_fill(stat_offset + d * 4, y_offset, 2, 8, shadow_color)
        gfx.rect_fill(stat_offset + d * 4, y_offset - 1, 2, 8, desc_color)
    end
    y_offset += 12
    if item.fire_rate then
        text_with_shadow("Fire Rate", 16, y_offset - 4, desc_color, shadow_color)
        for d = 1, math.log(6 / item.fire_rate, 1.125) do
            gfx.rect_fill(stat_offset + d * 4, y_offset, 2, 8, shadow_color)
            gfx.rect_fill(stat_offset + d * 4, y_offset - 1, 2, 8, desc_color)
        end
        y_offset += 12
    end
    if item.spread then
        text_with_shadow("Accuracy", 16, y_offset - 4, desc_color, shadow_color)
        for d = 1, math.max(1, 35 - item.spread) do
            gfx.rect_fill(stat_offset + d * 4, y_offset, 2, 8, shadow_color)
            gfx.rect_fill(stat_offset + d * 4, y_offset - 1, 2, 8, desc_color)
        end
        y_offset += 12
    end
    if item.range then
        text_with_shadow("Range", 16, y_offset - 4, desc_color, shadow_color)
        for d = 1, item.range / 8 do
            gfx.rect_fill(stat_offset + d * 4, y_offset, 2, 8, shadow_color)
            gfx.rect_fill(stat_offset + d * 4, y_offset - 1, 2, 8, desc_color)
        end
    end
end

local function draw_drawer()
    local max_height = 45
    if Drawer and Drawer_Height < max_height then
        Drawer_Height = util.clamp(Drawer_Height - 3 * math.log((1 - (Drawer_Height) / max_height)) + 1, 0,
            max_height)
        if Drawer_Height == max_height then
            conditional_screen_shake(0.25, 0.5)
        end
    end

    if not Drawer and Drawer_Height > 0 then
        Drawer_Height = util.clamp(Drawer_Height + 3 * math.log(((Drawer_Height) / max_height)) - 1, 0, max_height)
    end

    local h = usagi.GAME_H

    gfx.rect_fill(0, h - Drawer_Height, 320, h, gfx.COLOR_BLACK)
    gfx.line(0, h - Drawer_Height, 320, h - Drawer_Height, gfx.COLOR_TRUE_WHITE)

    local base_offset = -16

    if Selected_Turret and Turrets[Selected_Turret] and not Highlighted_Drawer_Item then
        draw_stats(Turrets[Selected_Turret])
    end

    local y = h + 15 - Drawer_Height
    local weapon_color = Drawer_Type == "weapon" and gfx.COLOR_YELLOW or
        (Highlighted_Tab == "weapon" and gfx.COLOR_WHITE or gfx.COLOR_LIGHT_GRAY)
    local turret_color = Drawer_Type == "turret" and gfx.COLOR_YELLOW or
        (Highlighted_Tab == "turret" and gfx.COLOR_WHITE or gfx.COLOR_LIGHT_GRAY)
    local grenade_color = Drawer_Type == "grenade" and gfx.COLOR_YELLOW or
        (Highlighted_Tab == "grenade" and gfx.COLOR_WHITE or gfx.COLOR_LIGHT_GRAY)
    local weapon_shadow = Drawer_Type == "weapon" and gfx.COLOR_BROWN or
        (Highlighted_Tab == "weapon" and gfx.COLOR_INDIGO or gfx.COLOR_DARK_GRAY)
    local turret_shadow = Drawer_Type == "turret" and gfx.COLOR_BROWN or
        (Highlighted_Tab == "turret" and gfx.COLOR_INDIGO or gfx.COLOR_DARK_GRAY)
    local grenade_shadow = Drawer_Type == "grenade" and gfx.COLOR_BROWN or
        (Highlighted_Tab == "grenade" and gfx.COLOR_INDIGO or gfx.COLOR_DARK_GRAY)
    text_with_shadow("[Weapons]", 16, y - 15, weapon_color, weapon_shadow)
    text_with_shadow("[Turrets]", 128, y - 15, turret_color, turret_shadow)
    text_with_shadow("[Grenades]", 244, y - 15, grenade_color, grenade_shadow)

    if Highlighted_Tab == "weapon" then
        gfx.line(18, y - 3, 67, y - 3, weapon_color)
        gfx.line(18, y - 2, 67, y - 2, weapon_shadow)
    elseif Highlighted_Tab == "turret" then
        gfx.line(130, y - 3, 179, y - 3, turret_color)
        gfx.line(130, y - 2, 179, y - 2, turret_shadow)
    elseif Highlighted_Tab == "grenade" then
        gfx.line(246, y - 3, 301, y - 3, grenade_color)
        gfx.line(246, y - 2, 301, y - 2, grenade_shadow)
    end

    for i, item in pairs(Drawer_Items) do
        local x = base_offset + i * 32
        if i == Highlighted_Drawer_Item then
            gfx.rect(x - 2, y - 2, 32, 32, gfx.COLOR_WHITE)
            draw_stats(item)
        end
        if item then
            if Drawer_Type == "turret" then
                gfx.sspr_ex(496, 496, 16, 16, x, y, 28, 28, false, false, 0, gfx.COLOR_DARK_GRAY, 0.5)
                local color = Money >= item.cost and gfx.COLOR_YELLOW or gfx.COLOR_LIGHT_GRAY
                local shadow = Money >= item.cost and gfx.COLOR_BROWN or gfx.COLOR_DARK_GRAY
                text_with_shadow("$" .. item.display_cost, x + 1, y + 16, color, shadow)
            elseif Drawer_Type == "weapon" then
                gfx.sspr_ex(496, 496, 16, 16, x, y, 28, 28, false, false, 0, gfx.COLOR_DARK_GRAY, 0.5)
                local color = ((Money >= item.cost or Discovered_Weapons[item.id]) and Weapon.id ~= item.id) and
                    gfx.COLOR_YELLOW or gfx.COLOR_LIGHT_GRAY
                local shadow = ((Money >= item.cost or Discovered_Weapons[item.id]) and Weapon.id ~= item.id) and
                    gfx.COLOR_BROWN or gfx.COLOR_DARK_GRAY
                local display = "$" .. item.display_cost
                if Discovered_Weapons[item.id] then
                    display = "FREE"
                end
                text_with_shadow(display, x + 1, y + 16, color, shadow)
            elseif Drawer_Type == "grenade" then
                gfx.sspr_ex(496, 496, 16, 16, x, y, 28, 28, false, false, 0, gfx.COLOR_DARK_GRAY, 0.5)
                local color = (Money >= item.cost and #Grenade_Inventory < Grenade_Slots) and
                    gfx.COLOR_YELLOW or gfx.COLOR_LIGHT_GRAY
                local shadow = (Money >= item.cost and #Grenade_Inventory < Grenade_Slots) and
                    gfx.COLOR_BROWN or gfx.COLOR_DARK_GRAY
                local display = "$" .. item.display_cost
                if #Grenade_Inventory >= Grenade_Slots then
                    display = "MAX"
                end
                text_with_shadow(display, x + 1, y + 16, color, shadow)
            end
        end
    end
end

local function draw_choices()
    local elapsed = usagi.elapsed - Transition_Started
    local w = 144
    local h = 100
    local text_1 = ""
    local text_2 = ""
    local color = gfx.COLOR_TRUE_WHITE
    local shadow = gfx.COLOR_INDIGO
    if Choice_Type == "unlock" then
        text_1 = "Continue your research."
        text_2 = "Add one to your shop."
    elseif Choice_Type == "mutation" then
        text_1 = "The horde evolves."
        text_2 = "Select a mutation."
        color = gfx.COLOR_RED
        shadow = gfx.COLOR_DARK_PURPLE
    else
        text_1 = "Empower yourself."
        text_2 = "Select an upgrade."
    end

    if elapsed > 1 and Choice_Progression == 0 then
        Choice_Progression = 1
        conditional_screen_shake(0.25, 0.25)
    end

    if Choice_Progression >= 1 then
        text_with_shadow(text_1, 8, 1, color, shadow)
        if elapsed > 2 and Choice_Progression == 1 then
            Choice_Progression = 2
            conditional_screen_shake(0.25, 0.25)
        end
    end
    if Choice_Progression >= 2 then
        text_with_shadow(text_2, #text_1 * 6 + 12, 1, color, shadow)
        if elapsed > 3 and Choice_Progression == 2 then
            Choice_Progression = 3
            conditional_screen_shake(0.25, 0.5)
        end
    end
    if Choice_Progression >= 3 then
        gfx.rect_fill(8, 15, w, h, gfx.COLOR_BLACK)
        if Highlighted_Choice == 1 then
            gfx.rect(6, 13, w + 4, h + 4, gfx.COLOR_TRUE_WHITE)
        end
        local type_size = #Choice_1.class * 6
        gfx.line(12, 29, w + 3, 29, gfx.COLOR_WHITE)
        text_with_shadow(Choice_1.name, 12, 15, gfx.COLOR_RED, gfx.COLOR_DARK_PURPLE)
        text_with_shadow(Choice_1.class, w + 4 - type_size, 15, gfx.COLOR_LIGHT_GRAY, gfx.COLOR_DARK_GRAY)
        text_with_shadow(Choice_1.description, 12, 31, gfx.COLOR_WHITE, gfx.COLOR_INDIGO)
        if Choice_Type == "mutation" then
            gfx.sspr_ex(Choice_1.spr_x, Choice_1.spr_y, 16, 16, 48, 40, 64, 64, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
        end
        if elapsed > 3.25 and Choice_Progression == 3 then
            Choice_Progression = 4
            conditional_screen_shake(0.25, 0.5)
        end
    end
    if Choice_Progression >= 4 then
        local type_size = #Choice_2.class * 6
        if Highlighted_Choice == 2 then
            gfx.rect(usagi.GAME_W - w - 10, 13, w + 4, h + 4, gfx.COLOR_TRUE_WHITE)
        end
        gfx.rect_fill(usagi.GAME_W - w - 8, 15, w, h, gfx.COLOR_BLACK)
        gfx.line(usagi.GAME_W - w - 4, 29, usagi.GAME_W - 13, 29, gfx.COLOR_WHITE)
        text_with_shadow(Choice_2.name, usagi.GAME_W - w - 4, 15, gfx.COLOR_RED, gfx.COLOR_DARK_PURPLE)
        text_with_shadow(Choice_2.class, usagi.GAME_W - w + 132 - type_size, 15, gfx.COLOR_LIGHT_GRAY,
            gfx.COLOR_DARK_GRAY)
        text_with_shadow(Choice_2.description, usagi.GAME_W - w - 4, 32, gfx.COLOR_WHITE, gfx.COLOR_INDIGO)
        if Choice_Type == "mutation" then
            gfx.sspr_ex(Choice_2.spr_x, Choice_2.spr_y, 16, 16, usagi.GAME_W - w + 32, 40, 64, 64, false, false, 0,
                gfx.COLOR_TRUE_WHITE, 1)
        end
        if elapsed > 4 and Choice_Progression == 4 then
            Choice_Progression = 5
        end
    end
end

local function draw_grenade_inventory()
    local offset = 3 * PLAYER_HEALTH

    for _, grenade in pairs(Grenade_Inventory) do
        offset += 10
        gfx.sspr(grenade.spr_x, grenade.spr_y, 16, 16, offset, 168)
    end

    if Is_Night and #Grenade_Inventory > 0 then
        gfx.sspr(304, 192, 16, 16, offset, 168)
    end
end

local function draw_grenades()
    for _, grenade in pairs(Grenades) do
        local rotation = (grenade.random * 8 - 4) * grenade.age * math.pi
        gfx.sspr_ex(grenade.spr_x, grenade.spr_y, 16, 16, grenade.cx - 8 * grenade.scale, grenade.cy - 8 * grenade.scale,
            16 * grenade.scale, 16 * grenade.scale, false, false, rotation, gfx.COLOR_TRUE_WHITE, 1)
    end
end

function _draw(dt)
    -- background
    gfx.clear(gfx.COLOR_BLACK)
    gfx.sspr_ex(0, 0, 320, 180, 0, 0, 320, 180, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)

    if not Is_Night then
        draw_turret_outlines()
    end
    draw_zombies()
    draw_turrets()
    draw_rampart()
    gfx.spr(513, 0, 137)
    draw_wall_zombies()
    if not Game_Over then
        draw_player()
    end
    draw_walls()
    draw_grenades()

    dandelion.Draw()

    -- night time tint
    if Is_Night then
        local alpha = math.min((usagi.elapsed - Transition_Started), 0.6)
        gfx.sspr_ex(496, 496, 16, 16, 0, 0, 320, 180, false, false, 0, gfx.COLOR_DARK_BLUE, alpha)
    else
        local alpha = math.max(0.6 - (usagi.elapsed - Transition_Started), 0)
        gfx.sspr_ex(496, 496, 16, 16, 0, 0, 320, 180, false, false, 0, gfx.COLOR_DARK_BLUE, alpha)
    end

    dandelion.DrawEmissive()

    draw_grenade_inventory()
    draw_hud()
    if Drawer or Drawer_Height > 0 then
        draw_drawer()
    end

    if Choice_1 and Choice_2 then
        draw_choices()
    end

    if not Is_Night and Player.x < 10 and not Choice_1 then
        text_with_shadow("[SPACE] Start Night", 0, 104, gfx.COLOR_RED, gfx.COLOR_DARK_PURPLE)
    end

    draw_crosshair()
    -- Game Over
end
