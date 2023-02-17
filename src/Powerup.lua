--[[
    -- Powerup Class --

    Randomly spawns a Powerup that the player must hit
    with their paddle to activate. When activated,
    it will spawn two additional balls.
]]
Powerup = Class {}

function Powerup:init(skin)
    self.x = math.random(32, VIRTUAL_WIDTH - 32)
    self.y = VIRTUAL_HEIGHT - 145
    self.dy = 0
    self.width = 16
    self.height = 16
    self.skin = skin

    -- set wait time before powerup is generated
    self.waitTime = 0

    -- set this status as true when it is in play
    self.active = false

    -- set this status as true when player has collected it
    self.collected = false
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt
end

function Powerup:render()
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.skin], self.x, self.y)
end

function Powerup:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end

    -- if the above aren't true, they're overlapping
    return true
end
