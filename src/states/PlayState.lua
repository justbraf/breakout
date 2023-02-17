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
    self.powerup = Powerup(9)
    self.powerup.dy = math.random(60, 70)
    self.powerup.waitTime = math.random(5, 15)
    self.spawnTimer = 0
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
    if self.spawnTimer > self.powerup.waitTime and not self.powerup.collected then
        self.powerup.active = true
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    -- update all ball objects in table
    for key, ball in pairs(self.ball) do
        ball:update(dt)
    end

    -- if powerup is active then update it
    if self.powerup.active and not self.powerup.collected then
        self.powerup:update(dt)
    end

    -- check if powerup passed the paddle and reached the edge
    if self.powerup.y >= VIRTUAL_HEIGHT then
        self.powerup.x = math.random(32, VIRTUAL_WIDTH - 32)
        self.powerup.y = VIRTUAL_HEIGHT - 145
        self.powerup.dy = math.random(60, 70)
        self.powerup.waitTime = math.random(5, 15)
        self.powerup.active = false
        self.spawnTimer = 0
    end
    -- check for powerup collision
    if self.powerup:collides(self.paddle) and not self.powerup.collected then
        self.powerup.collected = true
        self.powerup.active = false

        -- add two more ball objects
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

        gSounds['powerup']:play()
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
                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
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
            if table.getn(self.ball) == 1 then
                self.health = self.health - 1
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

    -- if powerup is in play then render it
    if self.powerup.active then
        self.powerup:render()
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
