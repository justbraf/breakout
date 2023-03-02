--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]
PlayState = Class { __includes = BaseState }

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores

    -- convert class variable into a table
    self.ball = {}
    -- add initial ball object that was passed in to the table
    table.insert(self.ball, params.ball)

    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    -- set properties for initial ball object
    self.ball[1].dx = math.random( -200, 200)
    self.ball[1].dy = math.random( -50, -60)

    -- initialize powerup
    self.powerup = {}
    self.powerup['ball'] = Powerup(9)
    self.powerup['key'] = Powerup(10)
    for k, pow in pairs(self.powerup) do
        pow.dy = math.random(60, 70)
        pow.waitTime = math.random(5, 15)
    end

    -- track the time for spawning
    self.spawnTimer = 0

    -- parameters for paddle upgrade
    self.paddleSize = self.paddle.size
    self.paddleWidths = { 32, 64, 96, 128 }

    -- points cap variable for upgrading paddle
    self.paddleUpgradePoints = self.score + 500
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- spawn timer tracks how much time has passed
    self.spawnTimer = self.spawnTimer + dt

    -- spawn powerup if its spawn time has elapsed
    for k, pow in pairs(self.powerup) do
        if self.spawnTimer > pow.waitTime and not pow.collected then
            pow.active = true
        end
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    -- update all ball objects in table
    for key, ball in pairs(self.ball) do
        ball:update(dt)
    end

    -- if powerup is active then update it
    for k, pow in pairs(self.powerup) do
        if pow.active and not pow.collected then
            pow:update(dt)

            -- check if powerup has passed the paddle and reached the edge
            -- if so, reset it for the next spawn
            if pow.y >= VIRTUAL_HEIGHT then
                pow.x = math.random(32, VIRTUAL_WIDTH - 32)
                pow.y = VIRTUAL_HEIGHT - 145
                pow.dy = math.random(60, 70)
                pow.waitTime = math.random(5, 15) + self.spawnTimer
                pow.active = false
                -- self.spawnTimer = 0
            end

            -- check for powerup collision
            if pow:collides(self.paddle) then
                pow.collected = true
                pow.active = false

                -- add two more ball objects if it is the ball powerup
                if k == 'ball' then
                    table.insert(self.ball, Ball())
                    table.insert(self.ball, Ball())

                    -- give two new balls random starting velocity and skins
                    for key, ball in pairs(self.ball) do
                        if key ~= 1 then
                            ball.x = self.paddle.x + (self.paddle.width / 2) - 4
                            ball.y = self.paddle.y - 8
                            ball.skin = math.random(7)
                            ball.dx = math.random( -200, 200)
                            ball.dy = math.random( -50, -60)
                        end
                    end
                end

                -- play sound effect to indicate powerup collected
                gSounds['powerup']:play()
            end
        end
    end


    -- check collisions for all balls
    for key, ball in pairs(self.ball) do
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

                -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        -- only check collision if we're in play
        -- check against all balls
        for key, ball in pairs(self.ball) do
            if brick.inPlay and ball:collides(brick) then
                -- perform brick functions for any brick except the lock brick (color 6) unless the powerup was collected
                if not (brick.color == 6 and brick.tier == 1) or self.powerup['key'].collected then
                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- if user score sufficient points then upgrade the paddle
                if self.score > self.paddleUpgradePoints then
                    -- I like this calculation for the points cap, so I reimplemented it
                    self.paddleUpgradePoints = self.paddleUpgradePoints + math.min(100000, self.paddleUpgradePoints * 2)

                    -- upgrade the paddle to the next size
                    self.paddleSize = math.min(4, self.paddleSize + 1)
                    -- update paddle size
                    self.paddle.size = self.paddleSize
                    -- update paddle width to match selected quad
                    self.paddle.width = self.paddleWidths[self.paddleSize]
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        -- only pass in the initial ball and discard te rest if they exist
                        ball = self.ball[1],
                        recoverPoints = self.recoverPoints
                        -- paddleUpgradePoints = self.paddleUpgradePoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8

                    -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                    -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32

                    -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8

                    -- bottom edge if no X collisions or top collision, last possibility
                else
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- as long as there is more than one ball in play, then delete the out of bound ball else
    -- if ball goes below bounds, revert to serve state and decrease health
    for key, ball in pairs(self.ball) do
        if ball.y >= VIRTUAL_HEIGHT then
            -- check for the last remaining ball
            if #self.ball == 1 then
                self.health = self.health - 1

                -- reduce paddle size because health was lost
                self.paddleSize = math.max(1, self.paddleSize - 1)
                -- update paddle size
                self.paddle.size = self.paddleSize
                -- update paddle width to match selected quad
                self.paddle.width = self.paddleWidths[self.paddleSize]

                gSounds['hurt']:play()

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                        -- paddleUpgradePoints = self.paddleUpgradePoints
                    })
                end
            else
                table.remove(self.ball, key)
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    -- render all ball objects
    for key, ball in pairs(self.ball) do
        ball:render()
    end

    -- if powerups are in play then render it
    for k, pow in pairs(self.powerup) do
        if pow.active then
            pow:render()
        end
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end
