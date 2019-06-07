require("utility\\animationList")
require("utility\\animation")
local RECT_FILL = "fill"
local RECT_STROKE = "stroke"
local RECT_FILL_STROKE = RECT_FILL .. RECT_STROKE
local animationLibrary = AnimationList:new()
local normalGaugeInnerColorAnimation = animationLibrary:create(0.01, 0, true)

gfx._ImageAlpha = 1

gfx._FillColor = gfx.FillColor
gfx._StrokeColor = gfx.StrokeColor
gfx._SetImageTint = gfx.SetImageTint

function gfx.FillColor(r, g, b, a)
    r = math.floor(r or 255)
    g = math.floor(g or 255)
    b = math.floor(b or 255)
    a = math.floor(a or 255)

    gfx._ImageAlpha = a / 255
    gfx._FillColor(r, g, b, a)
    gfx._SetImageTint(r, g, b)
end

function gfx.StrokeColor(r, g, b)
    r = math.floor(r or 255)
    g = math.floor(g or 255)
    b = math.floor(b or 255)

    gfx._StrokeColor(r, g, b)
end

function gfx.DrawRect(kind, x, y, w, h,alpha,rotation)
    if alpha==nil then
        alpha=1
    end
    if rotation==nil then
        rotation=0
    end

    local doFill = kind == RECT_FILL or kind == RECT_FILL_STROKE
    local doStroke = kind == RECT_STROKE or kind == RECT_FILL_STROKE

    local doImage = not (doFill or doStroke)
    gfx.BeginPath()

    if doImage then
        gfx.ImageRect(x, y, w, h, kind,alpha,rotation)
    else
        gfx.Rect(x, y, w, h)
        if doFill then gfx.Fill() end
        if doStroke then gfx.Stroke() end
    end
end

local buttonStates = { }
local buttonsInOrder = {
    game.BUTTON_BTA,
    game.BUTTON_BTB,
    game.BUTTON_BTC,
    game.BUTTON_BTD,

    game.BUTTON_FXL,
    game.BUTTON_FXR,

    game.BUTTON_STA,
}

function UpdateButtonStatesAfterProcessed()
    for i = 1, 6 do
        local button = buttonsInOrder[i]
        buttonStates[button] = game.GetButton(button)
    end
end

function game.GetButtonPressed(button)
    return game.GetButton(button) and not buttonStates[button]
end
-- -------------------------------------------------------------------------- --
-- game.IsUserInputActive:                                                    --
-- Used to determine if (valid) controller input is happening.                --
-- Valid meaning that laser motion will not return true unless the laser is   --
--  active in gameplay as well.                                               --
-- This restriction is not applied to buttons.                                --
-- The player may press their buttons whenever and the function returns true. --
-- Lane starts at 1 and ends with 8.                                          --
function game.IsUserInputActive(lane)
    if lane < 7 then
        return game.GetButton(buttonsInOrder[lane])
    end
    return gameplay.IsLaserHeld(lane - 7)
end
-- -------------------------------------------------------------------------- --
-- gfx.FillLaserColor:                                                        --
-- Sets the current fill color to the laser color of the given index.         --
-- An optional alpha value may be given as well.                              --
-- Index may be 1 or 2.                                                       --
function gfx.FillLaserColor(index, alpha)
    alpha = math.floor(alpha or 255)
    gfx.FillColor(255, 255, 255, alpha)
end
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
--                  The actual gameplay script starts here!                   --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Global data used by many things:                                           --
local resx, resy -- The resolution of the window
local portrait -- whether the window is in portrait orientation
local desw, desh -- The resolution of the deisign
local scale -- the scale to get from design to actual units
-- -------------------------------------------------------------------------- --
-- All images used by the script:                                             --
local jacketFallback = gfx.CreateSkinImage("song_select/loading.png", 0)
local bottomFill = gfx.CreateSkinImage("console/console.png", 0)
local topFill = gfx.CreateSkinImage("fill_top.png", 0)
local critAnim = gfx.CreateSkinImage("crit_anim.png", 0)
local critCap = gfx.CreateSkinImage("crit_cap.png", 0)
local critCapBack = gfx.CreateSkinImage("crit_cap_back.png", 0)
local laserCursor = gfx.CreateSkinImage("pointer.png", 0)
local laserCursorOverlay = gfx.CreateSkinImage("pointer_overlay.png", 0)
local normalGaugeInnerColor = gfx.CreateSkinImage("normalgauge_innercolor.png", gfx.IMAGE_REPEATX + gfx.IMAGE_REPEATY)
local hardGaugeInnerColor = gfx.CreateSkinImage("hardgauge_innercolor.png", gfx.IMAGE_REPEATX + gfx.IMAGE_REPEATY)

local ioConsoleDetails = {
    gfx.CreateSkinImage("console/detail_left.png", 0),
    gfx.CreateSkinImage("console/detail_right.png", 0),
}

local consoleAnimImages = {
    gfx.CreateSkinImage("console/glow_bta.png", 0),
    gfx.CreateSkinImage("console/glow_btb.png", 0),
    gfx.CreateSkinImage("console/glow_btc.png", 0),
    gfx.CreateSkinImage("console/glow_btd.png", 0),
    
    gfx.CreateSkinImage("console/glow_fxl.png", 0),
    gfx.CreateSkinImage("console/glow_fxr.png", 0),

    gfx.CreateSkinImage("console/glow_voll.png", 0),
    gfx.CreateSkinImage("console/glow_volr.png", 0),
}
-- -------------------------------------------------------------------------- --
-- Timers, used for animations:                                               --
local introTimer = 2
local outroTimer = 0

local alertTimers = {-2,-2}

local earlateTimer = 0
local critAnimTimer = 0

local consoleAnimSpeed = 10
local consoleAnimTimers = { 0, 0, 0, 0, 0, 0, 0, 0 }
-- -------------------------------------------------------------------------- --
-- Miscelaneous, currently unsorted:                                          --
local score = 0
local combo = 0
local jacket = nil
local critLinePos = { 0.95, 0.75 };
local comboScale = 1.0
local late = false
local diffNames = {"H", "DH", "SOS", "DMD"}
local clearTexts = {"The last judgement draweth nigh...", "Stage Cleared", "Stage Cleared", "Ultimate Chain", "Perfect" }
local comboFlashingLevel = 0.0
local comboFlashingPeriod = 4 / 60 
-- -------------------------------------------------------------------------- --
-- ResetLayoutInformation:                                                    --
-- Resets the layout values used by the skin.                                 --
function ResetLayoutInformation()
    resx, resy = game.GetResolution()
    portrait = resy > resx
    desw = portrait and 720 or 1280 
    desh = desw * (resy / resx)
    scale = resx / desw
end
-- -------------------------------------------------------------------------- --
-- render:                                                                    --
-- The primary & final render call.                                           --
-- Use this to render basically anything that isn't the crit line or the      --
--  intro/outro transitions.                                                  --
local currentGauge = 0
local previousGauge = 0
local isGaugeHasentUpTo70Percent = true
function render(deltaTime)
    previousGauge=currentGauge
    currentGauge=gameplay.gauge
    animationLibrary:update(deltaTime)
    if gameplay.gaugeType == 1 then
        gaugeHasentUpTo70Percent = false
    end
    -- make sure that our transform is cleared, clean working space
    -- TODO: this shouldn't be necessary!!!
    gfx.ResetTransform()
    local t = 0.0
    t, comboFlashingLevel = math.modf((comboFlashingLevel * comboFlashingPeriod + deltaTime) / comboFlashingPeriod )
    -- While the intro timer is running, we fade in from black
    local baseBoxX=-20
    local baseBoxY=-20
    local baseBoxW=10
    local baseBoxH=10
    if introTimer > 0 then
        baseBoxX=0
        baseBoxY=0
        baseBoxW=resx
        baseBoxH=resy
    end
    gfx.Save()
    gfx.FillColor(0, 0, 0, math.floor(255 * math.min(introTimer, 1)))
    gfx.DrawRect(RECT_FILL, baseBoxX, baseBoxY, baseBoxW, baseBoxH)
    gfx.Restore()
    gfx.Scale(scale, scale)
    local yshift = 0

    -- In portrait, we draw a banner across the top
    -- The rest of the UI needs to be drawn below that banner
    -- TODO: this isn't how it'll work in the long run, I don't think
    if portrait then yshift = draw_banner(deltaTime) end

    gfx.Translate(0, yshift - 150 * math.max(introTimer - 1, 0))
    draw_song_info(deltaTime)
    draw_score(deltaTime)
    draw_gauge(deltaTime)
    draw_earlate(deltaTime)
    draw_combo(deltaTime)
    draw_alerts(deltaTime)
    if previousGauge<0.7 and currentGauge>=0.7 then 
        isGaugeHasentUpTo70Percent = false
    end
end
-- -------------------------------------------------------------------------- --
-- SetUpCritTransform:                                                        --
-- Utility function which aligns the graphics transform to the center of the  --
--  crit line on screen, rotation include.                                    --
-- This function resets the graphics transform, it's up to the caller to      --
--  save the transform if needed.                                             --
function SetUpCritTransform()
    -- start us with a clean empty transform
    gfx.ResetTransform()
    -- translate and rotate accordingly
    gfx.Translate(gameplay.critLine.x, gameplay.critLine.y)
    gfx.Rotate(-gameplay.critLine.rotation)
end
-- -------------------------------------------------------------------------- --
-- GetCritLineCenteringOffset:                                                --
-- Utility function which returns the magnitude of an offset to center the    --
--  crit line on the screen based on its position and rotation.               --
function GetCritLineCenteringOffset()
    local distFromCenter = resx / 2 - gameplay.critLine.x
    local dvx = math.cos(gameplay.critLine.rotation)
    local dvy = math.sin(gameplay.critLine.rotation)
    return math.sqrt(dvx * dvx + dvy * dvy) * distFromCenter
end
-- -------------------------------------------------------------------------- --
-- render_crit_base:                                                          --
-- Called after rendering the highway and playable objects, but before        --
--  the built-in hit effects.                                                 --
-- This is the first render function to be called each frame.                 --
-- This call resets the graphics transform, it's up to the caller to          --
--  save the transform if needed.                                             --
function render_crit_base(deltaTime)
    -- Kind of a hack, but here (since this is the first render function
    --  that gets called per frame) we update the layout information.
    -- This means that the player can resize their window and
    --  not break everything
    ResetLayoutInformation()

    critAnimTimer = critAnimTimer + deltaTime
    SetUpCritTransform()
    
    -- Figure out how to offset the center of the crit line to remain
    --  centered on the players screen
    local xOffset = GetCritLineCenteringOffset()
    gfx.Translate(xOffset, 0)
    
    -- Draw a transparent black overlay below the crit line
    -- This darkens the play area as it passes
    gfx.FillColor(0, 0, 0, 200)
    gfx.DrawRect(RECT_FILL, -resx, 0, resx * 2, resy)

    -- The absolute width of the crit line itself
    -- we check to see if we're playing in portrait mode and
    --  change the width accordingly
    local critWidth = resx * (portrait and 1 or 0.8)
    
    -- get the scaled dimensions of the crit line pieces
    local clw, clh = gfx.ImageSize(critAnim)
    local critAnimHeight = 15 * scale
    local critAnimWidth = critAnimHeight * (clw / clh)

    local ccw, cch = gfx.ImageSize(critCap)
    local critCapHeight = critAnimHeight * (cch / clh)
    local critCapWidth = critCapHeight * (ccw / cch)

    -- draw the back half of the caps at each end
    do
        gfx.Save()
        gfx.FillColor(255, 255, 255)
        -- left side
        gfx.DrawRect(critCapBack, -critWidth / 2 - critCapWidth / 2, -critCapHeight / 2, critCapWidth, critCapHeight)
        gfx.Scale(-1, 1) -- scale to flip horizontally
        -- right side
        gfx.DrawRect(critCapBack, -critWidth / 2 - critCapWidth / 2, -critCapHeight / 2, critCapWidth, critCapHeight)
        gfx.Scale(-1, 1) -- unflip horizontally
        gfx.Restore()
    end

    -- render the core of the crit line
    do
        -- The crit line is made up of many small pieces scrolling outward
        -- Calculate how many pieces, starting at what offset, are require to
        --  completely fill the space with no gaps from edge to center
        local numPieces = 1 + math.ceil(critWidth / (critAnimWidth * 2))
        local startOffset = critAnimWidth * ((critAnimTimer * 1.5) % 1)
        gfx.Save()
        -- left side
        -- Use a scissor to limit the drawable area to only what should be visible
        gfx.Scissor(-critWidth / 2, -critAnimHeight / 2, critWidth / 2, critAnimHeight)
        for i = 1, numPieces do
            gfx.DrawRect(critAnim, -startOffset - critAnimWidth * (i - 1), -critAnimHeight / 2, critAnimWidth, critAnimHeight)
        end
        gfx.ResetScissor()

        -- right side
        -- exactly the same, but in reverse
        gfx.Scissor(0, -critAnimHeight / 2, critWidth / 2, critAnimHeight)
        for i = 1, numPieces do
            gfx.DrawRect(critAnim, -critAnimWidth + startOffset + critAnimWidth * (i - 1), -critAnimHeight / 2, critAnimWidth, critAnimHeight)
        end
        gfx.ResetScissor()
        gfx.Restore()
    end

    -- Draw the front half of the caps at each end
    do
        gfx.Save()
        gfx.FillColor(255, 255, 255)
        -- left side
        gfx.DrawRect(critCap, -critWidth / 2 - critCapWidth / 2, -critCapHeight / 2, critCapWidth, critCapHeight)
        gfx.Scale(-1, 1) -- scale to flip horizontally
        -- right side
        gfx.DrawRect(critCap, -critWidth / 2 - critCapWidth / 2, -critCapHeight / 2, critCapWidth, critCapHeight)
        gfx.Scale(-1, 1) -- unflip horizontally
        gfx.Restore()
    end

    -- we're done, reset graphics stuffs
    gfx.ResetTransform()
end
-- -------------------------------------------------------------------------- --
-- render_crit_overlay:                                                       --
-- Called after rendering built-int crit line effects.                        --
-- Use this to render laser cursors or an IO Console in portrait mode!        --
-- This call resets the graphics transform, it's up to the caller to          --
--  save the transform if needed.                                             --
function render_crit_overlay(deltaTime)
    SetUpCritTransform()

    -- Figure out how to offset the center of the crit line to remain
    --  centered on the players screen.
    local xOffset = GetCritLineCenteringOffset()

    -- When in portrait, we can draw the console at the bottom
    if portrait then
        -- We're going to make temporary modifications to the transform
        gfx.Save()
        gfx.Translate(xOffset * 0.5, 0)

        local bfw, bfh = gfx.ImageSize(bottomFill)

        local distBetweenKnobs = 0.446
        local distCritVertical = 0.098

        local ioFillTx = bfw / 2
        local ioFillTy = bfh * distCritVertical -- 0.098

        -- The total dimensions for the console image
        local io_x, io_y, io_w, io_h = -ioFillTx, -ioFillTy, bfw, bfh

        -- Adjust the transform accordingly first
        local consoleFillScale = (resx * 0.775) / (bfw * distBetweenKnobs)
        gfx.Scale(consoleFillScale, consoleFillScale);

        -- Actually draw the fill
        gfx.FillColor(255, 255, 255)
        gfx.DrawRect(bottomFill, io_x, io_y, io_w, io_h)

        -- Then draw the details which need to be colored to match the lasers
        for i = 1, 2 do
            gfx.FillLaserColor(i)
            gfx.DrawRect(ioConsoleDetails[i], io_x, io_y, io_w, io_h)
        end

        -- Draw the button press animations by overlaying transparent images
        gfx.GlobalCompositeOperation(gfx.BLEND_OP_LIGHTER)
        for i = 1, 6 do
            -- While a button is held, increment a timer
            -- If not held, that timer is set back to 0
            if game.GetButton(buttonsInOrder[i]) then
                consoleAnimTimers[i] = consoleAnimTimers[i] + deltaTime * consoleAnimSpeed * 3.14 * 2
            else 
                consoleAnimTimers[i] = 0
            end

            -- If the timer is active, flash based on a sin wave
            local timer = consoleAnimTimers[i]
            if timer ~= 0 then
                local image = consoleAnimImages[i]
                local alpha = (math.sin(timer) * 0.5 + 0.5) * 0.5 + 0.25
                gfx.FillColor(255, 255, 255, alpha * 255);
                gfx.DrawRect(image, io_x, io_y, io_w, io_h)
            end
        end
        gfx.GlobalCompositeOperation(gfx.BLEND_OP_SOURCE_OVER)
        
        -- Undo those modifications
        gfx.Restore();
    end

    local cw, ch = gfx.ImageSize(laserCursor)
    local cursorWidth = 40 * scale
    local cursorHeight = cursorWidth * (ch / cw)

    -- draw each laser cursor
    for i = 1, 2 do
        local cursor = gameplay.critLine.cursors[i - 1]
        local pos, skew = cursor.pos, cursor.skew

        -- Add a kinda-perspective effect with a horizontal skew
        gfx.SkewX(skew)

        -- Draw the colored background with the appropriate laser color
        gfx.FillLaserColor(i, cursor.alpha * 255)
        gfx.DrawRect(laserCursor, pos - cursorWidth / 2, -cursorHeight / 2, cursorWidth, cursorHeight)
        -- Draw the uncolored overlay on top of the color
        gfx.FillColor(255, 255, 255, cursor.alpha * 255)
        gfx.DrawRect(laserCursorOverlay, pos - cursorWidth / 2, -cursorHeight / 2, cursorWidth, cursorHeight)
        -- Un-skew
        gfx.SkewX(-skew)
    end

    -- We're done, reset graphics stuffs
    gfx.FillColor(255, 255, 255)
    gfx.ResetTransform()
end
-- -------------------------------------------------------------------------- --
-- draw_banner:                                                               --
-- Renders the banner across the top of the screen in portrait.               --
-- This function expects no graphics transform except the design scale.       --
function draw_banner(deltaTime)
    local bannerWidth, bannerHeight = gfx.ImageSize(topFill)
    local actualHeight = desw * (bannerHeight / bannerWidth)

    gfx.FillColor(255, 255, 255)
    gfx.DrawRect(topFill, 0, 0, desw, actualHeight)

    return actualHeight
end
-- -------------------------------------------------------------------------- --
-- draw_stat:                                                                 --
-- Draws a formatted name + value combination at x, y over w, h area.         --
function draw_stat(x, y, w, h, name, value, format, r, g, b)
    gfx.Save()

    -- Translate from the parent transform, wherever that may be
    gfx.Translate(x, y)

    -- Draw the `name` top-left aligned at `h` size
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP)
    gfx.FontSize(h)
    gfx.Text(name .. ":", 0, 0) -- 0, 0, is x, y after translation

    -- Realign the text and draw the value, formatted
    gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_TOP)
    gfx.Text(string.format(format, value), w, 0)
    -- This draws an underline beneath the text
    -- The line goes from 0, h to w, h
    gfx.BeginPath()
    gfx.MoveTo(0, h)
    gfx.LineTo(w, h) -- only defines the line, does NOT draw it yet

    -- If a color is provided, set it
    if r then gfx.StrokeColor(r, g, b) 
    -- otherwise, default to a light grey
    else gfx.StrokeColor(200, 200, 200) end

    -- Stroke out the line
    gfx.StrokeWidth(1)
    gfx.Stroke()
    -- Undo our transform changes
    gfx.Restore()

    -- Return the next `y` position, for easier vertical stacking
    return y + h + 5
end
-- -------------------------------------------------------------------------- --
-- draw_song_info:                                                            --
-- Draws current song information at the top left of the screen.              --
-- This function expects no graphics transform except the design scale.       --
function draw_song_info(deltaTime)
    local songInfoWidth = 400
    local jacketWidth = 100
    -- Check to see if there's a jacket to draw, and attempt to load one if not
    if jacket == nil or jacket == jacketFallback then
        jacket = gfx.LoadImageJob(gameplay.jacketPath, jacketFallback)
    end

    gfx.Save()

    -- Add a small margin at the edge
    gfx.Translate(5,5)
    -- There's less screen space in portrait, the playable area is effectively a square
    -- We scale down to take up less space
    if portrait then gfx.Scale(0.7, 0.7) end

    -- Ensure the font has been loaded
    gfx.LoadSkinFont("fot-udkakugoc80pro-r.ttf")

    gfx.FillColor(255, 255, 255)
    gfx.DrawRect(jacket, 100, 30, jacketWidth, jacketWidth)


--[[     -- Draw the background, a simple grey box
    gfx.FillColor(20, 20, 20, 200)
    gfx.DrawRect(RECT_FILL, 0, 0, songInfoWidth, 100)
    -- Draw the jacket
    gfx.FillColor(255, 255, 255)
    gfx.DrawRect(jacket, 0, 0, jacketWidth, jacketWidth)
    -- Draw a background for the following level stat
    gfx.FillColor(0, 0, 0, 200)
    gfx.DrawRect(RECT_FILL, 0, 85, 60, 15)
    -- Level Name : Level Number
    gfx.FillColor(255, 255, 255)
    draw_stat(0, 85, 55, 15, diffNames[gameplay.difficulty + 1], gameplay.level, "%02d")
    -- Reset some text related stuff that was changed in draw_state
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT)
    gfx.FontSize(24)
    
    gfx.FillColor(255, 255, 255)
    
    local textX = jacketWidth + 10
    local titleWidth = songInfoWidth - jacketWidth - 20
    local x1, y1, x2, y2 = gfx.TextBounds(0, 0, gameplay.title)
    local textscale = math.min(titleWidth / x2, 1)
    
    gfx.Save()
    do  -- Draw the song title, scaled to fit as best as possible
        gfx.Translate(textX, 30)
        gfx.Scale(textscale, textscale)
        gfx.Text(gameplay.title, 0, 0)
    end
    gfx.Restore()

    x1,y1,x2,y2 = gfx.TextBounds(0,0,gameplay.artist)
    textscale = math.min(titleWidth / x2, 1)

    gfx.Save()
    do  -- Draw the song artist, scaled to fit as best as possible
        gfx.Translate(textX, 60)
        gfx.Scale(textscale, textscale)
        gfx.Text(gameplay.artist, 0, 0)
    end
    gfx.Restore()

    -- Draw the BPM
    gfx.FontSize(14)
    gfx.Text(string.format("BPM: %.1f", gameplay.bpm), textX, 85)

    -- Fill the progress bar
    gfx.FillColor(0, 150, 255)
    gfx.DrawRect(RECT_FILL, jacketWidth, jacketWidth - 10, (songInfoWidth - jacketWidth) * gameplay.progress, 10)
    -- When the player is holding Start, the hispeed can be changed
    -- Shows the current hispeed values
    if game.GetButton(game.BUTTON_STA) then
        gfx.FillColor(20, 20, 20, 200);
        gfx.DrawRect(RECT_FILL, 100, 100, songInfoWidth - 100, 20)

        gfx.FillColor(255, 255, 255)
        gfx.Text(string.format("HiSpeed: %.0f x %.1f = %.0f",
                gameplay.bpm, gameplay.hispeed, gameplay.bpm * gameplay.hispeed),
                textX, 115)
    end

    -- aaaand, scene! ]]
    gfx.Restore()
end
-- -------------------------------------------------------------------------- --
-- draw_best_diff:                                                            --
-- If there are other saved scores, this displays the difference between      --
--  the current play and your best.                                           --
function draw_best_diff(deltaTime, x, y)
    -- Don't do anything if there's nothing to do
    if not gameplay.scoreReplays[1] then return end

    -- Calculate the difference between current and best play
    local difference = score - gameplay.scoreReplays[1].currentScore
    local prefix = "" -- used to properly display negative values
    gfx.Save()
    gfx.BeginPath()
    gfx.FontSize(40)

    gfx.FillColor(255, 255, 255)
    if difference < 0 then
        -- If we're behind the best score, separate the minus sign and change the color
        gfx.FillColor(255, 50, 50)
        difference = math.abs(difference)
        prefix = "-"
    end

    -- %08d formats a number to 8 characters
    -- This includes the minus sign, so we do that separately
    gfx.Text(string.format("%s%08d", prefix, difference), x, y)
    gfx.Restore()
end
-- -------------------------------------------------------------------------- --
-- draw_score:                                                                --
function draw_score(deltaTime)
    gfx.Save()
    gfx.BeginPath()
    gfx.LoadSkinFont("dmc5font.ttf")
    gfx.BeginPath()
    gfx.RoundedRectVarying(desw - 210, 5, 220, 62, 0, 0, 0, 20)
    gfx.FillColor(20, 20, 20)
    gfx.StrokeColor(0, 128, 255)
    gfx.StrokeWidth(2)
    gfx.Fill()
    gfx.Stroke()
    gfx.Translate(-5, 5) -- upper right margin
    gfx.FillColor(255, 255, 255)
    gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_TOP)
    gfx.FontSize(60)
    gfx.Text(string.format("%08d", score), desw, 0)
    draw_best_diff(deltaTime, desw, 66)
    gfx.Translate(5, -5) -- undo margin
    gfx.Restore()
end
-- -------------------------------------------------------------------------- --
-- draw_gauge:                                                                --
local damagedGaugeAnimationCount = 0
local damagedGaugeAnimationValue = 0
local damagedGaugeAnimationFlag = false
function draw_gauge(deltaTime)
    gfx.Save()
    gfx.Translate(0,0)
    if gameplay.gaugeType == 0 then
        local height = 50--512* scale * 0.35
        local width = 300--1024 * scale * 0.35
        local posy = 50 --resy / 6 - height / 2
        local posx = 300 --resx/5 - width * (1 - math.max(introTimer - 1, 0))
        if portrait then
            width = width * 0.8
            height = height * 0.8
            posy = posy - 30
            posx = resx - width * (1 - math.max(introTimer - 1, 0))
        end
        local scaleBlock10=1.3
        local scaleBlock80=1
        local widthBlock10=width/(scaleBlock10*7+scaleBlock80*3)*scaleBlock10
        local widthBlock80=width/(scaleBlock10*7+scaleBlock80*3)*scaleBlock80    
        for i = 0, 9 do
            local blockPercent = 0
            if currentGauge*100 - i*10 < 0 then
                blockPercent = 0
            else 
                if currentGauge*100 - i*10 > 10 then
                    blockPercent = 1
                else   
                    blockPercent = (currentGauge*100 - i*10) / 10
                end 
            end
            local bs
            local bx 
            local bw
            if i<=6 then 
                bs=scaleBlock10
                bx=posx+widthBlock10*i
                bw=widthBlock10
            else
                bs=scaleBlock80
                bx=posx+widthBlock10*7+widthBlock80*(i-7)
                bw=widthBlock80
            end
            
            draw_normal_gauge_block(bx,posy,bw,height*bs/scaleBlock10,blockPercent,currentGauge>=0.7)
        end
        draw_normal_gauge_box(posx,posy,width,height,scaleBlock10,scaleBlock80,deltaTime)
    else
        local height = 40--512* scale * 0.35
        local width = 500--1024 * scale * 0.35
        local posy = 50 --resy / 6 - height / 2
        local posx = 300 --resx/5 - width * (1 - math.max(introTimer - 1, 0))
        if portrait then
            width = width * 0.8
            height = height * 0.8
            posy = posy - 30
            posx = resx - width * (1 - math.max(introTimer - 1, 0))
        end
        if currentGauge < previousGauge or damagedGaugeAnimationFlag then
            update_hard_gauge_damaged(deltaTime)
        end
        for i = 0, 1 do
            local offsetY = height * 7 / 10
            for j = 0, 9 do
                local blockPercent = 0
                local damagedPercent = 0
                if currentGauge*100 - (i * 50 + j * 5) > 5 then
                    blockPercent = 1
                    damagedPercent = 0
                else 
                    local packedGauge = currentGauge + damagedGaugeAnimationCount
                    if currentGauge*100 - (i * 50 + j * 5) < 0 then
                        blockPercent = 0
                        if packedGauge * 100 - (i * 50 + j * 5) > 5 then
                            damagedPercent = 1
                        else
                            if packedGauge * 100 - (i * 50 + j * 5) < 0 then
                                damagedPercent = 0
                            else
                                damagedPercent = (packedGauge * 100 - (i * 50 + j * 5)) / 5
                            end
                        end
                    else
                        blockPercent = (currentGauge*100 - (i * 50 + j * 5)) / 5
                        if packedGauge * 100 - (i * 50 + j * 5) > 5 then
                            damagedPercent = 1 - blockPercent
                        else
                            if packedGauge * 100 - (i * 50 + j * 5) < 0 then
                                damagedPercent = 0
                            else
                                damagedPercent = (packedGauge * 100 - (i * 50 + j * 5)) / 5 - blockPercent
                            end
                        end
                    end
                end
                draw_hard_gauge_block(posx+j*width/10,posy+offsetY*i,width/10,height*3/10,blockPercent,damagedPercent,currentGauge>=0.3,i*10+j)
            end
        end
    end
    gfx.Restore()
	--draw gauge % label
	-- posx = posx / scale
	-- posx = posx + (100 * 0.35) 
	-- height = 880 * 0.35
	-- posy = posy / scale
	-- if portrait then
	-- 	height = height * 0.8;
	-- end

	-- posy = posy + (70 * 0.35) + height - height * gameplay.gauge
	-- gfx.BeginPath()
	-- gfx.Rect(posx-35, posy-10, 40, 20)
	-- gfx.FillColor(0,0,0,200)
	-- gfx.Fill()
	-- gfx.FillColor(255,255,255)
	-- gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_MIDDLE)
	-- gfx.FontSize(20)
    -- gfx.Text(string.format("%d%%", math.floor(gameplay.gauge * 100)), posx, posy )

end

function draw_normal_gauge_block(x,y,w,h,blockPercent,isPass)
    local rf=0
    local gf=103
    local bf=211
    local rb=32
    local gb=41
    local bb=49
    if isPass then
        rf=188
        gf=96
        bf=255
        rb=43
        gb=36
        bb=49
    end
    local defaltGrey = 20
    local rr = math.modf(defaltGrey + (rf - defaltGrey) * blockPercent)
    local gr = math.modf(defaltGrey + (gf - defaltGrey) * blockPercent)
    local br = math.modf(defaltGrey + (bf - defaltGrey) * blockPercent) 
    gfx.Save()
    gfx.BeginPath()
    gfx.GradientColors(rr,gr,br,255,rr,gr,br,255)
    local solidColor = gfx.LinearGradient(x+w/2,y,x+w/2-h/4,y+h)
    gfx.StrokeColor(rb,gb,bb)
    gfx.StrokeWidth(2)
    gfx.MoveTo(x+w/8,y)
    gfx.LineTo(x-w/8+w,y)
    gfx.LineTo(x-w/8+w-h/2,y+h)
    gfx.LineTo(x+w/8-h/2,y+h)
    gfx.ClosePath()
    gfx.FillPaint(solidColor)
    gfx.Fill()
    gfx.Stroke()
    local backWidth, backHeight = gfx.ImageSize(normalGaugeInnerColor)
    local backPattern = gfx.ImagePattern(0, backHeight * normalGaugeInnerColorAnimation.progress, backWidth, backHeight, 0, normalGaugeInnerColor, 1)
    gfx.GlobalCompositeOperation(gfx.BLEND_OP_DESTINATION_IN)
    gfx.MoveTo(x+w/8,y)
    gfx.LineTo(x-w/8+w,y)
    gfx.LineTo(x-w/8+w-h/2,y+h)
    gfx.LineTo(x+w/8-h/2,y+h)
    gfx.ClosePath()
    gfx.FillPaint(backPattern)
    gfx.Fill()
    gfx.GlobalCompositeOperation(gfx.BLEND_OP_SOURCE_OVER)
    gfx.Restore()
end
local firstPassGaugeAnimationValue = 0
local firstPassGaugeAnimationFlag = false

function draw_normal_gauge_first_pass_box(x,y,w,h,scaleBlock10,scaleBlock80,deltaTime)
    firstPassGaugeAnimationFlag = true

    local widthBlock10=w/(scaleBlock10*7+scaleBlock80*3)*scaleBlock10
    local widthBlock80=w/(scaleBlock10*7+scaleBlock80*3)*scaleBlock80
    local heightBlock80=h*scaleBlock80/scaleBlock10
    local offset10X=h/2
    local offset80X=heightBlock80/2
    if firstPassGaugeAnimationValue <= 1 then
        for i = 0, 6 do
            local scaleOffsetX = widthBlock10 / 2 * (1 - firstPassGaugeAnimationValue^2)
            local scaleOffsetY = h / 2 * (1 - firstPassGaugeAnimationValue^2)
            local scaleHeight = h + scaleOffsetY * 2
            gfx.Save()
            gfx.BeginPath()
            local alpha = 255 * firstPassGaugeAnimationValue
            gfx.StrokeColor(214,179,255,alpha)
            gfx.StrokeWidth(3)
            gfx.MoveTo(x+widthBlock10/8-scaleOffsetX+widthBlock10*i,y-scaleOffsetY)
            gfx.LineTo(x-widthBlock10/8+widthBlock10+scaleOffsetX+widthBlock10*i,y-scaleOffsetY)
            gfx.LineTo(x-widthBlock10/8+widthBlock10+scaleOffsetX+widthBlock10*i-scaleHeight/2,y+h+scaleOffsetY)
            gfx.LineTo(x+widthBlock10/8+widthBlock10*i-scaleOffsetX-scaleHeight/2,y+h+scaleOffsetY)
            gfx.ClosePath()
            gfx.Stroke()
            gfx.Restore()
        end 
    end
    if firstPassGaugeAnimationValue > 1 and firstPassGaugeAnimationValue < 2 then
        
    end
    firstPassGaugeAnimationValue = firstPassGaugeAnimationValue + deltaTime*1.5
    if firstPassGaugeAnimationValue >= 2 then
        firstPassGaugeAnimationFlag = false
        firstPassGaugeAnimationValue = 0
    end
end
local normalGaugeAnimationValue = 0
local normalGaugeAnimationDirection = 0
function draw_normal_gauge_box(x,y,w,h,scaleBlock10,scaleBlock80,deltaTime)
    if currentGauge>=0.7 and previousGauge < 0.7 then
        normalGaugeAnimationDirection = 1
        if isGaugeHasentUpTo70Percent then
            draw_normal_gauge_first_pass_box(x,y,w,h,scaleBlock10,scaleBlock80,deltaTime)
        end
    else
        if currentGauge<0.7 and previousGauge >=0.7 then
            normalGaugeAnimationDirection=-1
        end
    end
    normalGaugeAnimationValue=normalGaugeAnimationValue+deltaTime*2*normalGaugeAnimationDirection
    if normalGaugeAnimationValue>1 then
        normalGaugeAnimationValue=1
    else
        if normalGaugeAnimationValue<0 then
            normalGaugeAnimationValue=0
        end
    end
    local blockCount = math.floor(currentGauge*10)
    local widthBlock10=w/(scaleBlock10*7+scaleBlock80*3)*scaleBlock10
    local widthBlock80=w/(scaleBlock10*7+scaleBlock80*3)*scaleBlock80
    local heightBlock80=h*scaleBlock80/scaleBlock10
    local offset10X=h/2
    local offset80X=heightBlock80/2
    local x1 = x
    local y1 = y
    local x2 = x+ widthBlock10*7+widthBlock80*(blockCount-7)*math.ceil((blockCount-7)/7)
    local y2 = y
    local x3 = x + widthBlock10*7+widthBlock80*(blockCount-7)*math.ceil((blockCount-7)/7) - offset10X
    local y3 = y + h
    local x4 = x + widthBlock10*7 - offset10X
    local y4 = y + h
    if blockCount >= 8 then
        x3 = x + widthBlock10*7+widthBlock80*(blockCount-7) - offset80X
        x4 = x + widthBlock10*7 - offset80X
        y3 = y + heightBlock80
        y4 = y + heightBlock80
    end
    local x5 = x + widthBlock10*7 - offset10X
    local y5 = y + h
    local x6 = x - offset10X
    local y6 = y + h
    if normalGaugeAnimationValue==0 and currentGauge<0.7 then 
        return
    end
    gfx.Save()
    gfx.BeginPath()
    gfx.MoveTo(x1,y1)
    gfx.LineTo(x2,y2)
    gfx.LineTo(x3,y3)
    gfx.LineTo(x4,y4)
    gfx.LineTo(x5,y5)
    gfx.LineTo(x6,y6)
    gfx.ClosePath()
    local alpha = 255 * normalGaugeAnimationValue
    gfx.StrokeColor(214,179,255,alpha)
    gfx.StrokeWidth(3)
    gfx.Stroke()
    gfx.Restore()
    if (currentGauge>=0.7 and previousGauge < 0.7 and isGaugeHasentUpTo70Percent) or firstPassGaugeAnimationFlag then
        draw_normal_gauge_first_pass_box(x,y,w,h,scaleBlock10,scaleBlock80,deltaTime)
    end
end
function update_hard_gauge_damaged(deltaTime)
    damagedGaugeAnimationFlag = true
    damagedGaugeAnimationCount = damagedGaugeAnimationCount + previousGauge - currentGauge
    if damagedGaugeAnimationValue >= 0.8 then
        damagedGaugeAnimationCount = damagedGaugeAnimationCount - deltaTime / 3
    end
    damagedGaugeAnimationValue = damagedGaugeAnimationValue + deltaTime
    if damagedGaugeAnimationCount <= 0 then
        damagedGaugeAnimationFlag = false
        damagedGaugeAnimationValue = 0
        damagedGaugeAnimationCount = 0
    end
end

function draw_hard_gauge_block(x,y,w,h,blockPercent,damagedPercent,isDangerous,randomSeed)
    gfx.Save()
    math.randomseed(randomSeed)
    local randomRotate = math.random(0,360)/180*math.pi
    local backWidth, backHeight=gfx.ImageSize(hardGaugeInnerColor)
    local drawBlock = function(blockX,blockY,width,height,r,g,b)
        gfx.GradientColors(r,g,b,255,r,g,b,255)
        local solidColor = gfx.LinearGradient(0, 0, resx, resy)
        local backPattern = gfx.ImagePattern(0, 0, backWidth * 2, backHeight * 2, randomRotate, hardGaugeInnerColor, 1)
        gfx.Scissor(blockX,blockY,width,height)
        gfx.BeginPath()
        gfx.Rect(0,0,resx,resy)
        gfx.FillPaint(solidColor)
        gfx.Fill()
        gfx.BeginPath()
        gfx.Rect(blockX,blockY,width,height)
        gfx.GlobalCompositeOperation(gfx.BLEND_OP_DESTINATION_IN)
        gfx.FillPaint(backPattern)
        gfx.Fill()
        gfx.ResetScissor()
        gfx.GlobalCompositeOperation(gfx.BLEND_OP_SOURCE_OVER)
   end

    if blockPercent > 0 then
        drawBlock(x,y,w*blockPercent,h,0,207,138)
    end
    if damagedPercent > 0 then
        drawBlock(x+w*blockPercent,y,w*damagedPercent,h,187,64,65)
    end
    if damagedPercent + blockPercent < 1 then
        drawBlock(x+w*(blockPercent+damagedPercent),y,w*(1-blockPercent-damagedPercent),h,43,42,45)
    end

    gfx.BeginPath()
    gfx.StrokeColor(5,32,9)
    gfx.StrokeWidth(2)
    gfx.DrawRect(RECT_STROKE,x,y,w,h)
    gfx.Restore()
end
-- -------------------------------------------------------------------------- --
-- draw_combo:                                                                --
function draw_combo(deltaTime)
    if combo == 0 then return end
    local posx = desw / 2
    local posy = desh * critLinePos[1] - 100
    if portrait then posy = desh * critLinePos[2] - 150 end
    gfx.Save()
    gfx.BeginPath()
    gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
    if gameplay.comboState == 2 then
        gfx.FillColor(255,230,40,100+100*comboFlashingLevel) --puc
        gfx.LoadSkinFont("dmc5font.ttf")
    elseif gameplay.comboState == 1 then
        gfx.FillColor(255,200,0,100+100*comboFlashingLevel) --uc
        gfx.LoadSkinFont("dmc5font.ttf")
    else
        gfx.FillColor(255,255,255,100+100*comboFlashingLevel) --regular
        gfx.LoadSkinFont("dmc5fontblock.ttf")
    end
    gfx.FontSize(16 * math.max(comboScale, 1))
    gfx.Text("- CHAIN -", posx, posy-40)
    gfx.FontSize(70 * math.max(comboScale, 1))
    gfx.Text(tostring(combo), posx, posy)
    comboScale = comboScale - deltaTime * 3
    gfx.Restore()
end
-- -------------------------------------------------------------------------- --
-- draw_earlate:                                                              --
function draw_earlate(deltaTime)
    earlateTimer = math.max(earlateTimer - deltaTime,0)
    if earlateTimer == 0 then return nil end
    local alpha = math.floor(earlateTimer * 20) % 2
    alpha = alpha * 200 + 55
    gfx.BeginPath()
    if gameplay.comboState >=1 then
        gfx.LoadSkinFont("dmc5font.ttf")
    else
        gfx.LoadSkinFont("dmc5fontblock.ttf")
    end
    gfx.FontSize(20)
    gfx.TextAlign(gfx.TEXT_ALIGN_CENTER, gfx.TEXT_ALIGN_MIDDLE)
    local ypos = desh * critLinePos[1] - 160
    if portrait then ypos = desh * critLinePos[2] - 160 end
    if late then
        gfx.FillColor(29,217,228, alpha)
        gfx.Text("> LATE <", desw / 2, ypos)
    else
        gfx.FillColor(227,75,216, alpha)
        gfx.Text("> EARLY <", desw / 2, ypos)
    end
end
-- -------------------------------------------------------------------------- --
-- draw_alerts:                                                               --
function draw_alerts(deltaTime)
    alertTimers[1] = math.max(alertTimers[1] - deltaTime,-2)
    alertTimers[2] = math.max(alertTimers[2] - deltaTime,-2)
    if alertTimers[1] > 0 then --draw left alert
        gfx.Save()
        local posx = desw / 2 - 350
        local posy = desh * critLinePos[1] - 135
        if portrait then 
            posy = desh * critLinePos[2] - 135 
            posx = 65
        end
        gfx.Translate(posx,posy)
        local alertScale = (-(alertTimers[1] ^ 2.0) + (1.5 * alertTimers[1])) * 5.0
        alertScale = math.min(alertScale, 1)
        if gameplay.comboState >=1 then
            gfx.LoadSkinFont("dmc5font.ttf")
        else
            gfx.LoadSkinFont("dmc5fontblock.ttf")
        end    
        gfx.Scale(1, alertScale)
        gfx.BeginPath()
        gfx.FillColor(29,217,228)
        gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
        gfx.FontSize(90)
        gfx.Text("L",0,0)
        gfx.FontSize(20)
        gfx.Text("— LEFT LASER ALERT —",0,50)
        gfx.Restore()
    end
    if alertTimers[2] > 0 then --draw right alert
        gfx.Save()
        local posx = desw / 2 + 350
        local posy = desh * critLinePos[1] - 135
        if portrait then 
            posy = desh * critLinePos[2] - 135 
            posx = desw - 65
        end
        if gameplay.comboState >=1 then
            gfx.LoadSkinFont("dmc5font.ttf")
        else
            gfx.LoadSkinFont("dmc5fontblock.ttf")
        end    
        gfx.Translate(posx,posy)
        local alertScale = (-(alertTimers[2] ^ 2.0) + (1.5 * alertTimers[2])) * 5.0
        alertScale = math.min(alertScale, 1)
        gfx.Scale(1, alertScale)
        gfx.BeginPath()
        gfx.FillColor(227,75,216)
        gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
        gfx.FontSize(90)
        gfx.Text("R",0,0)
        gfx.FontSize(20)
        gfx.Text("— RIGHT LASER ALERT —",0,50)
        gfx.Restore()
    end
end
-- -------------------------------------------------------------------------- --
-- render_intro:                                                              --
function render_intro(deltaTime)
    if not game.GetButton(game.BUTTON_STA) then
        introTimer = introTimer - deltaTime
    end
    introTimer = math.max(introTimer, 0)
    return introTimer <= 0
end
-- -------------------------------------------------------------------------- --
-- render_outro:                                                              --
function render_outro(deltaTime, clearState)
    if clearState == 0 then return true end
    gfx.ResetTransform()
    gfx.BeginPath()
    gfx.Rect(0,0,resx,resy)
    gfx.FillColor(0,0,0, math.floor(127 * math.min(outroTimer, 1)))
    gfx.Fill()
    gfx.Scale(scale,scale)
    gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
    gfx.FillColor(255,255,255, math.floor(255 * math.min(outroTimer, 1)))
    gfx.LoadSkinFont("dmc5font.ttf")
    gfx.FontSize(70)
    gfx.Text(clearTexts[clearState], desw / 2, desh / 2)
    outroTimer = outroTimer + deltaTime
    return outroTimer > 2, 1 - outroTimer
end
-- -------------------------------------------------------------------------- --
-- update_score:                                                              --
function update_score(newScore)
    score = newScore
end
-- -------------------------------------------------------------------------- --
-- update_combo:                                                              --
function update_combo(newCombo)
    combo = newCombo
    comboScale = 1.2
end
-- -------------------------------------------------------------------------- --
-- near_hit:                                                                  --
function near_hit(wasLate) --for updating early/late display
    late = wasLate
    earlateTimer = 0.75
end
-- -------------------------------------------------------------------------- --
-- laser_alert:                                                               --
function laser_alert(isRight) --for starting laser alert animations
    if isRight and alertTimers[2] < -1.5 then
        alertTimers[2] = 1.5
    elseif alertTimers[1] < -1.5 then
        alertTimers[1] = 1.5
    end
end