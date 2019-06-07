--Horizontal alignment
TEXT_ALIGN_LEFT 	= 1
TEXT_ALIGN_CENTER 	= 2
TEXT_ALIGN_RIGHT 	= 4
--Vertical alignment
TEXT_ALIGN_TOP 		= 8
TEXT_ALIGN_MIDDLE	= 16
TEXT_ALIGN_BOTTOM	= 32
TEXT_ALIGN_BASELINE	= 64

local jacket = nil;
local currentSelectedSongIndex = 1
local previousSelectedSongIndex = 0
local selectedDiff = 1
local songCache = {}
local ioffset = 0
local doffset = 0
local soffset = 0
local diffColors = {{83,199,203}, {124,233,113}, {242,56,65}, {255, 77, 238}}
local timer = 0
local effector = 0
local searchText = gfx.CreateLabel("",5,0)
local searchIndex = 1
local jacketFallback = gfx.CreateSkinImage("song_select/loading.png", 0)
local diffIconBack = gfx.CreateSkinImage("diff_icon_back.png", 0)
local diffIconBorder = gfx.CreateSkinImage("diff_icon_border.png", 0)
local separator = gfx.CreateSkinImage("separator.png", 0)
gfx.LoadSkinFont("fot-udkakugoc80pro-r.ttf");
local legendTable = {
  {["labelSingleLine"] =  gfx.CreateLabel("DIFFICULTY SELECT",24, 0), ["labelMultiLine"] =  gfx.CreateLabel("DIFFICULTY\nSELECT",24, 0), ["image"] = gfx.CreateSkinImage("legend/knob-left.png", 0)},
  {["labelSingleLine"] =  gfx.CreateLabel("MUSIC SELECT",24, 0),      ["labelMultiLine"] =  gfx.CreateLabel("MUSIC\nSELECT",24, 0),      ["image"] = gfx.CreateSkinImage("legend/knob-right.png", 0)},
  {["labelSingleLine"] =  gfx.CreateLabel("FILTER MUSIC",24, 0),      ["labelMultiLine"] =  gfx.CreateLabel("FILTER\nMUSIC",24, 0),      ["image"] = gfx.CreateSkinImage("legend/FX-L.png", 0)},
  {["labelSingleLine"] =  gfx.CreateLabel("MUSIC MODS",24, 0),        ["labelMultiLine"] =  gfx.CreateLabel("MUSIC\nMODS",24, 0),        ["image"] = gfx.CreateSkinImage("legend/FX-LR.png", 0)},
  {["labelSingleLine"] =  gfx.CreateLabel("PLAY",24, 0),              ["labelMultiLine"] =  gfx.CreateLabel("PLAY",24, 0),               ["image"] = gfx.CreateSkinImage("legend/start.png", 0)},
  {["labelSingleLine"] =  gfx.CreateLabel("RETURN",24, 0),            ["labelMultiLine"] =  gfx.CreateLabel("RETURN",24, 0),               ["image"] = gfx.CreateSkinImage("legend/BT-ESC.png", 0)}
}
local grades = {
  {["max"] = 6999999, ["image"] = gfx.CreateSkinImage("score/D.png", 0)},
  {["max"] = 7999999, ["image"] = gfx.CreateSkinImage("score/C.png", 0)},
  {["max"] = 8699999, ["image"] = gfx.CreateSkinImage("score/B.png", 0)},
  {["max"] = 8999999, ["image"] = gfx.CreateSkinImage("score/A.png", 0)},
  {["max"] = 9299999, ["image"] = gfx.CreateSkinImage("score/A+.png", 0)},
  {["max"] = 9499999, ["image"] = gfx.CreateSkinImage("score/AA.png", 0)},
  {["max"] = 9699999, ["image"] = gfx.CreateSkinImage("score/AA+.png", 0)},
  {["max"] = 9799999, ["image"] = gfx.CreateSkinImage("score/AAA.png", 0)},
  {["max"] = 9899999, ["image"] = gfx.CreateSkinImage("score/AAA+.png", 0)},
  {["max"] = 99999999, ["image"] = gfx.CreateSkinImage("score/S.png", 0)}
}
local titleMusicSelectImage = gfx.CreateSkinImage("title_music_select.png",0)
local badges = {
    gfx.CreateSkinImage("badges/noplay.png", 0),
    gfx.CreateSkinImage("badges/played.png", 0),
    gfx.CreateSkinImage("badges/clear.png", 0),
    gfx.CreateSkinImage("badges/hard-clear.png", 0),
    gfx.CreateSkinImage("badges/full-combo.png", 0),
    gfx.CreateSkinImage("badges/perfect.png", 0)
}

gfx.LoadSkinFont("segoeui.ttf");

game.LoadSkinSample("menu_click")
game.LoadSkinSample("click-02")
game.LoadSkinSample("woosh")

local wheelSize = 12

get_page_size = function()
    return math.floor(wheelSize/2)
end

-- Responsive UI variables
-- Aspect Ratios
local aspectFloat = 1.850
local aspectRatio = "widescreen"
local landscapeWidescreenRatio = 1.850
local landscapeStandardRatio = 1.500
local portraitWidescreenRatio = 0.5

-- Responsive sizes
local fifthX = 0
local fourthX= 0
local thirdX = 0
local halfX  = 0
local fullX  = 0

local fifthY = 0
local fourthY= 0
local thirdY = 0
local halfY  = 0
local fullY  = 0


adjustScreen = function(x,y)
  local a = x/y;
  if x >= y and a <= landscapeStandardRatio then
    aspectRatio = "landscapeStandard"
    aspectFloat = 1.1
  elseif x >= y and landscapeStandardRatio <= a and a <= landscapeWidescreenRatio then
    aspectRatio = "landscapeWidescreen"
    aspectFloat = 1.2
  elseif x <= y and portraitWidescreenRatio <= a and a < landscapeStandardRatio then
    aspectRatio = "PortraitWidescreen"
    aspectFloat = 0.5
  else
    aspectRatio = "landscapeWidescreen"
    aspectFloat = 1.0
  end
  fifthX = x/5
  fourthX= x/4
  thirdX = x/3
  halfX  = x/2
  fullX  = x

  fifthY = y/5
  fourthY= y/4
  thirdY = y/3
  halfY  = y/2
  fullY  = y
end


check_or_create_cache = function(song, loadJacket)
    if not songCache[song.id] then songCache[song.id] = {} end

    if not songCache[song.id]["title"] then
        songCache[song.id]["title"] = gfx.CreateLabel(song.title, 30, 0)
    end

    if not songCache[song.id]["artist"] then
        songCache[song.id]["artist"] = gfx.CreateLabel(song.artist, 25, 0)
    end

    if not songCache[song.id]["bpm"] then
        songCache[song.id]["bpm"] = gfx.CreateLabel(string.format("BPM: %s",song.bpm), 20, 0)
    end

    if not songCache[song.id]["jacket"] and loadJacket then
        songCache[song.id]["jacket"] = gfx.CreateImage(song.difficulties[1].jacketPath, 0)
    end
end

draw_scores = function(difficulty, x, y, w, h)
  -- draw the top score for this difficulty  
  gfx.LoadSkinFont("dmc5fontblock.ttf")
  gfx.BeginPath();
  gfx.Rect(x,y+h/24,w,h/24-h/128)
  gfx.FillColor(0,0,0,0)
  gfx.Fill()
  gfx.FillColor(181,201,207)
  gfx.FontSize(h/4)
  gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_CENTER)
  gfx.Text("HIGH SCORE",x+30,y+h/6);
  gfx.BeginPath();
  gfx.ImageRect(x,y+h/12+h/8-h/64,w,h/64,separator,1,0)

	local xOffset = 224
  local height = h/3 - 10
  local ySpacing = h/3
  local yOffset = h/5
  gfx.BeginPath()
  gfx.Rect(x+xOffset,y+h/2,w-(xOffset*2),h/2)
  gfx.FillColor(30,30,30,10)
  gfx.Fill()
	if difficulty.scores[1] ~= nil then
		local highScore = difficulty.scores[1]
    for i,v in ipairs(grades) do
      if v.max > highScore.score then
        gfx.BeginPath()
        iw,ih = gfx.ImageSize(v.image)
        iar = iw / ih;
        gfx.ImageRect(x+w-xOffset,y+yOffset, 130,137, v.image, 1, 0)
        break
      end
    end  
    gfx.FillColor(163,211,216)
    gfx.FontSize(75);
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP);
    gfx.Text(string.format("%08d",highScore.score), x+60,y+h/12+h/8+h/24,w)
	end
  gfx.BeginPath()
  if difficulty.scores[1] == nil then
    gfx.ImageRect(x+33, y+h/12+h/8+h/24, 671,40, badges[difficulty.topBadge+1], 1, 0)
  else
    gfx.ImageRect(x+33, y+h/12+h/8+h/24+70, 671,40, badges[difficulty.topBadge+1], 1, 0)
  end
end

local songCursorFadeInAnimation = {index = 0, value = 0}
local songCursorFadeInAnimationVeolocity = 0.75
local songCursorFadeOutAnimationTable = {}
local songCursorFadeOutAnimationVeolocity = 0.75
draw_song = function(song, x, y, w, h, wheelIndex, deltaTime)
  check_or_create_cache(song)
  local isCurrentSelected = wheelIndex == currentSelectedSongIndex
  local isPreviousSelected = wheelIndex == previousSelectedSongIndex
  local backX = x + 9
  local textOffsetY = 9
  local realHeight = h

  local drawBackSelected = function (animationValue)
    gfx.Scissor(backX, y, w, realHeight)
    gfx.BeginPath()
    gfx.MoveTo(backX, y)
    gfx.LineTo(backX + w * animationValue, y)
    gfx.LineTo(backX + w * animationValue - realHeight / 2, y + realHeight)
    gfx.LineTo(backX, y + realHeight)
    gfx.ClosePath()

    gfx.FillColor(0, 29, 52)
    gfx.Fill()
    gfx.ResetScissor()
  end

  if isCurrentSelected then
    local i = songCursorFadeInAnimation.index
    if i ~= wheelIndex then
      songCursorFadeInAnimation.index = wheelIndex
      songCursorFadeInAnimation.value = 0
    end
    local v = songCursorFadeInAnimation.value
    drawBackSelected(v)
    gfx.FillColor(122, 233, 247)
    gfx.TextAlign(gfx.TEXT_ALIGN_MIDDLE + gfx.TEXT_ALIGN_LEFT)
    gfx.DrawLabel(songCache[song.id]["title"], x + 30, y + h / 2 + textOffsetY, w-10)  
  else
    local fof = false
    local animation = nil
    for k, v in ipairs(songCursorFadeOutAnimationTable) do
      if v.index == wheelIndex then
        fof = true
        animation = v
        break
      end
    end
    if not fof and isPreviousSelected then
      animation = {index = wheelIndex, value = 1}
      table.insert(songCursorFadeOutAnimationTable, animation)
    end
    if animation then
      drawBackSelected(animation.value)
      gfx.FillColor(math.modf(186-(186-122)*animation.value),math.modf(186-(186-233)*animation.value),math.modf(186-(186-247)*animation.value),255)
      local textAnimationValue = 20 - (1 - animation.value) * w / 40
      if textAnimationValue < 0 then
        textAnimationValue = 0
      end
      gfx.TextAlign(gfx.TEXT_ALIGN_MIDDLE + gfx.TEXT_ALIGN_LEFT)
      gfx.DrawLabel(songCache[song.id]["title"], x + 10 + textAnimationValue, y + h / 2 + textOffsetY, w-10)  
      else
        drawBackSelected(0)
        gfx.FillColor(186,186,186)
        gfx.TextAlign(gfx.TEXT_ALIGN_MIDDLE + gfx.TEXT_ALIGN_LEFT)
        gfx.DrawLabel(songCache[song.id]["title"], x + 10, y + h / 2 + textOffsetY, w-10)  
      end
  end
  songCursorFadeInAnimation.value = songCursorFadeInAnimation.value + deltaTime * songCursorFadeInAnimationVeolocity
  if songCursorFadeInAnimation.value > 1 then
    songCursorFadeInAnimation.value = 1
  end
  for k = #songCursorFadeOutAnimationTable, 1, -1 do
    songCursorFadeOutAnimationTable[k].value = songCursorFadeOutAnimationTable[k].value - deltaTime * songCursorFadeOutAnimationVeolocity
    if songCursorFadeOutAnimationTable[k].value <= 0 then
      if songCursorFadeOutAnimationTable[k].index == previousSelectedSongIndex then
        previousSelectedSongIndex = 0
      end
      table.remove(songCursorFadeOutAnimationTable, k)
    end
  end
  gfx.ForceRender()
end

draw_diff_icon = function(diff, x, y, w, h, selected)
  local shrinkX = w/4
  local shrinkY = h/4
  if selected then
    gfx.LoadSkinFont("dmc5font.ttf")
    gfx.FontSize(h/2)
    shrinkX = w/6
    shrinkY = h/6
  else
    gfx.LoadSkinFont("dmc5fontblock.ttf")
    gfx.FontSize(math.floor(h / 2.3))
  end
  gfx.BeginPath()
  if selected then
    gfx.ImageRect(x+shrinkX,y+shrinkY,w-shrinkX*2,h-shrinkY*2,diffIconBack,1,0)
  else
    gfx.RoundedRectVarying(x+shrinkX,y+shrinkY,w-shrinkX*2,h-shrinkY*2,0,1,1,0)   
    gfx.FillColor(0,0,0,0)
    gfx.StrokeColor(0,0,0,0)
    gfx.StrokeWidth(0)
    gfx.Fill()
    gfx.Stroke()
  end
  gfx.FillColor(255,255,255)
  local textOffsetX = 0
  local textOffsetY = 2
  gfx.TextAlign(gfx.TEXT_ALIGN_MIDDLE + gfx.TEXT_ALIGN_CENTER)
  gfx.FastText(tostring(diff.level), x+(w/2)+textOffsetX, y+(h/2)+textOffsetY)
end

draw_diff_icon_border = function(diff,x,y,animationValue,width)
  gfx.Save()
  gfx.BeginPath()
  gfx.Translate(x,y)
  gfx.SetImageTint(table.unpack(diffColors[diff.difficulty + 1]))
  gfx.ImageRect(-width/2, -width/2, width, width, diffIconBorder, 0.3+0.7*animationValue, 0)
  gfx.Fill()
  gfx.SetImageTint(255,255,255)
  gfx.Translate(-x,-y)
  gfx.Restore()
end

local diffNames = {"HUMAN", "DEVICE HUNTER", "SONG OF SPECIALIST", "DRAGON MUST DIE"}

draw_diffs = function(diffs, x, y, w, h)
    local diffWidth = h/1.6
    local diffHeight = h/1.6
    local diffCount = #diffs
    local offsetY = 40
    gfx.Scissor(x,y,w,h)
    gfx.LoadSkinFont("dmc5fontblock.ttf")
    gfx.BeginPath();
    gfx.Rect(x,y+h/12,w,h/12-h/64)
    gfx.FillColor(0,0,0,0)
    gfx.Fill()
    gfx.FillColor(181,201,207)
    gfx.FontSize(h/4)
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_CENTER)
    gfx.Text("GAME MODE",x+30,y+h/6);

    gfx.BeginPath()
    gfx.ImageRect(x,y+h/12+h/8-h/64,w,h/64,separator,1,0)
    local diff = diffs[selectedDiff]
    gfx.BeginPath();
    gfx.MoveTo(x+w/24,y+h/8+h/12+h/24)
    gfx.LineTo(x+w*11/12,y+h/8+h/12+h/24)
    gfx.LineTo(x+w*11/12,y+h/8+4*h/12+h/24)
    gfx.LineTo(x+w/24+h/8,y+h/8+4*h/12+h/24)
    gfx.ClosePath()
    gfx.GradientColors(20,168,182,200,6,43,74,255)
    local backGradient = gfx.LinearGradient(x,y+h/8+h/12+h/24,x+w*11/12,y+h/8+h/12+h/24)
    gfx.FillPaint(backGradient)
    gfx.Fill()
    gfx.GradientColors(181,201,207,255,258,239,251,255)
    local textGradient = gfx.LinearGradient(x+w/2,y+h/4,x+w/2,y+h/2)
    gfx.FontSize(h/4)
    gfx.TextAlign(gfx.TEXT_ALIGN_MIDDLE + gfx.TEXT_ALIGN_CENTER)
    gfx.FillPaint(textGradient)
    gfx.Text(diffNames[diff.difficulty+1],x+w/2,y+h/8+h/4)

   for i = math.max(selectedDiff - 2, 1), math.max(selectedDiff - 1,1) do
      diff = diffs[i]
      local xpos = x + ((w/2 - diffWidth/2) + (selectedDiff - i + doffset)*(-0.8*diffWidth))
      if  i ~= selectedDiff then
        draw_diff_icon(diff, xpos, y+h/8+4*h/12+h/24, diffWidth, diffHeight, false)
      end
    end

    --after selected
  for i = math.min(selectedDiff + 2, diffCount), selectedDiff + 1,-1 do
      diff = diffs[i]
      local xpos = x + ((w/2 - diffWidth/2) + (selectedDiff - i + doffset)*(-0.8*diffWidth))
      if  i ~= selectedDiff then
        draw_diff_icon(diff, xpos, y+h/8+4*h/12+h/24, diffWidth, diffHeight, false)
      end
  end
  diff = diffs[selectedDiff]
  local xpos = x + ((w/2 - diffWidth/2) + (doffset)*(-0.8*diffWidth))
  draw_diff_icon(diff, xpos, y+h/8+4*h/12+h/24, diffWidth, diffHeight, true)
  gfx.ResetScissor()
  draw_diff_icon_border(diff,x + w/2, y+h/8+4*h/12+h/24+diffHeight/2, math.abs(math.sin(timer * math.pi)), diffHeight / 1.5)
end

draw_info = function(song,x,y,w,h)
  y=y+h/4
  gfx.LoadSkinFont("dmc5fontblock.ttf")
  gfx.BeginPath();
  gfx.Rect(x,y+h/24,w,h/24-h/128)
  gfx.FillColor(0,0,0,0)
  gfx.Fill()
  gfx.FillColor(181,201,207)
  gfx.FontSize(h/8)
  gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_CENTER)
  gfx.Text("INFORMATION",x+30,y+h/12);
  gfx.BeginPath();
  gfx.ImageRect(x,y+h/24+h/16-h/128,w,h/128,separator,1,0)
  y=y+h/12
  local imageSize = math.floor(h/2)
  local imageXPos = x+w-imageSize-w/16-h/12
  local labelXPos = x+40
  local yPos = y+h/24+h/16
  gfx.LoadSkinFont("fot-udkakugoc80pro-r.ttf")
  local effector = gfx.CreateLabel(song.difficulties[selectedDiff].effector,20,0)
  gfx.FillColor(181,201,207)
  if aspectRatio == "PortraitWidescreen" then
    gfx.FontSize(40)
    gfx.TextAlign(gfx.TEXT_ALIGN_TOP + gfx.TEXT_ALIGN_LEFT)
    gfx.DrawLabel(songCache[song.id]["title"], labelXPos, y+yMargin+yPadding, w-imageSize-w/16+h/6)
    gfx.FontSize(30)
    gfx.DrawLabel(songCache[song.id]["artist"], labelXPos+3, y+yMargin+yPadding + 45, w-imageSize+h/6-20)
    gfx.FontSize(20)
    gfx.DrawLabel(songCache[song.id]["bpm"], labelXPos+3, y+yMargin+yPadding + 85, w-imageSize+h/6-w/16)
    gfx.FastText("Effector:", labelXPos+3, y+yMargin+yPadding + 115)
    gfx.DrawLabel(effector, labelXPos+80, y+yMargin+yPadding + 115, w-imageSize+h/6-w/16)
  else
    gfx.FontSize(40)
    gfx.TextAlign(gfx.TEXT_ALIGN_TOP + gfx.TEXT_ALIGN_LEFT)
    gfx.DrawLabel(songCache[song.id]["title"], labelXPos, yPos,w-imageSize+h/6-w/16)
    gfx.FontSize(30)
    gfx.DrawLabel(songCache[song.id]["artist"], labelXPos, yPos+ 45, w-imageSize+h/6-w/16)
    gfx.FontSize(20)
    gfx.DrawLabel(songCache[song.id]["bpm"], labelXPos, yPos + 85)
    gfx.FastText("Effector:",labelXPos, yPos + 115)
    gfx.DrawLabel(effector, labelXPos+75, yPos + 115,w-imageSize+h/6-w/16-75)
  end
  if aspectRatio == "PortraitWidescreen" then
    --Unless its portrait widesreen..
    imageSize = math.floor((h/3)*2)
    imageXPos = x+xMargin+xPadding
  end
  if not songCache[song.id][selectedDiff] or songCache[song.id][selectedDiff] ==  jacketFallback then
    songCache[song.id][selectedDiff] = gfx.LoadImageJob(song.difficulties[selectedDiff].jacketPath, jacketFallback, 200,200)
  end
  if songCache[song.id][selectedDiff] then
    gfx.BeginPath()
    gfx.ImageRect(imageXPos,yPos, imageSize, imageSize, songCache[song.id][selectedDiff], 1, 0)
  end
end


draw_selected = function(song, x, y, w, h)
    check_or_create_cache(song)
    -- set up padding and margins
    local width = w
    local height = h
    local xpos = x
    local ypos = y
    if aspectRatio == "PortraitWidescreen" then
      xPadding = math.floor(w/64)
      yPadding =  math.floor(h/32)
      xMargin = math.floor(w/64)
      yMargin =  math.floor(h/32)
      width = (w-(xMargin*2))
      height = (h-(yMargin*2))
      xpos = x+xMargin
      ypos = y+yMargin
    end
    local baseHeight
    if aspectRatio == "PortraitWidescreen" then
      baseHeight=height/3
    else
      baseHeight=height/6
    end
    draw_force(x+w*3/4,y,w/12,baseHeight/1.5,deltaTime)
    draw_info(song,x,y+baseHeight/3,w,math.floor(baseHeight*2))
    --Border
    local diff = song.difficulties[selectedDiff]
    -- jacket should take up 1/3 of height, always be square, and be centered
    -- difficulty should take up 1/6 of height, full width, and be centered
    if aspectRatio == "PortraitWidescreen" then
      --difficulty wheel should be right below the jacketImage, and the same width as
      --the jacketImage
      draw_diffs(song.difficulties,x,y+baseHeight/3+2*baseHeight,w,math.floor(baseHeight))
    else
      -- difficulty should take up 1/6 of height, full width, and be centered
      draw_diffs(song.difficulties,x,y+baseHeight/3+2*baseHeight,w,math.floor(baseHeight))
    end
    -- effector / bpm should take up 1/3 of height, full width
    if aspectRatio == "PortraitWidescreen" then
      draw_scores(diff, x,  y+baseHeight/3+3*baseHeight, width, baseHeight)
    else
      draw_scores(diff, x,y+baseHeight/3+3*baseHeight, width, baseHeight)
    end
    gfx.ForceRender()
end

draw_songwheel = function(x,y,w,h,deltaTime)
  local offsetX = 30
  local elementOffsetY = 10
  local width = math.floor((w/5)*4)
  if aspectRatio == "landscapeWidescreen" then
    wheelSize = 8
    offsetX = -640
  elseif aspectRatio == "landscapeStandard" then
    wheelSize = 10
    offsetX = 40
  elseif aspectRatio == "PortraitWidescreen" then
    wheelSize = 20
    offsetX = 20
    width = w
  end
  local height = math.floor((h/wheelSize)*1.3)

  for i = math.max(currentSelectedSongIndex - wheelSize/2, 1), math.max(currentSelectedSongIndex - 1,0) do
      local song = songwheel.songs[i]
      local xpos = x + offsetX 
      local offsetY = (currentSelectedSongIndex - i + ioffset) * ( height - (wheelSize/2*(ioffset*aspectFloat))) + elementOffsetY
      local ypos = y+((h/2 - height/2) - offsetY)
      draw_song(song, xpos, ypos, width, height, i, deltaTime)
  end

  --after selected
  for i = math.min(currentSelectedSongIndex + wheelSize/2, #songwheel.songs), currentSelectedSongIndex + 1,-1 do
      local song = songwheel.songs[i]
      local xpos = x + offsetX
      local offsetY = (currentSelectedSongIndex - i + ioffset) * ( height - (wheelSize/2*(-ioffset*aspectFloat))) - elementOffsetY
      local ypos = y+((h/2 - height/2) - (currentSelectedSongIndex - i) - offsetY)
      local alpha = 255 - (currentSelectedSongIndex - i + ioffset) * 31
      draw_song(song, xpos, ypos, width, height, i, deltaTime)
  end
  -- draw selected
  local xpos = x + offsetX
  local offsetY = (ioffset) * ( height - (wheelSize/2*((1)*aspectFloat)))
  local ypos = y+((h/2 - height/2) - (ioffset) - offsetY)
  draw_song(songwheel.songs[currentSelectedSongIndex], xpos, ypos, width, height, currentSelectedSongIndex, deltaTime)
  return songwheel.songs[currentSelectedSongIndex]
end

draw_legend_pane = function(x,y,imageScale,obj)
  local xpos = x+5
  local ypos = y+10
  local imageWidth, imageHeight = gfx.ImageSize(obj.image) 
  imageWidth=imageWidth*imageScale
  imageHeight=imageHeight*imageScale
  gfx.BeginPath()
  gfx.TextAlign(gfx.TEXT_ALIGN_MIDDLE + gfx.TEXT_ALIGN_LEFT)
  gfx.ImageRect(x-imageWidth/2, y-imageHeight/2, imageWidth, imageHeight, obj.image, 1, 0)
  xpos = xpos + imageWidth / 2 + 5
  gfx.FontSize(16);
  if imageHeight > 5 then
    gfx.DrawLabel(obj.labelSingleLine, xpos, ypos, 1000)
  else
    gfx.DrawLabel(obj.labelMultiLine, xpos, ypos, 1000)
  end
  gfx.ForceRender()
end

draw_legend = function(x,y,w,h)
  local xpos = 140;
  local legendWidth = {293,240,237,237,135,180}
  local totalWidth = 0
  for i,v in ipairs(legendTable) do
    local xOffset = draw_legend_pane(xpos+totalWidth, y+50,0.7,legendTable[i])
    totalWidth = totalWidth + legendWidth[i]
  end
end

draw_search = function(x,y,w,h)
  soffset = soffset + (searchIndex) - (songwheel.searchInputActive and 0 or 1)
  if searchIndex ~= (songwheel.searchInputActive and 0 or 1) then
      game.PlaySample("woosh")
  end
  searchIndex = songwheel.searchInputActive and 0 or 1

  gfx.BeginPath()
  local bgfade = 1 - (searchIndex + soffset)
  --if not songwheel.searchInputActive then bgfade = soffset end
  gfx.FillColor(0,0,0,math.floor(200 * bgfade))
  gfx.Rect(0,0,resx,resy)
  gfx.Fill()
  gfx.ForceRender()
  local xpos = x + (searchIndex + soffset)*w
  gfx.UpdateLabel(searchText ,string.format("Search: %s",songwheel.searchText), 30, 0)
  gfx.BeginPath()
  gfx.RoundedRect(xpos,y,w,h,h/2)
  gfx.FillColor(30,30,30)
  gfx.StrokeColor(0,128,255)
  gfx.StrokeWidth(1)
  gfx.Fill()
  gfx.Stroke()
  gfx.BeginPath();
  gfx.LoadSkinFont("segoeui.ttf");
  gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_MIDDLE);
  gfx.DrawLabel(searchText, xpos+10,y+(h/2), w-20)

end

render = function(deltaTime)
  timer = (timer + deltaTime)
  timer = timer % 2
  resx,resy = game.GetResolution();
  adjustScreen(resx,resy);
  if aspectRatio == "PortraitWidescreen" then
  else
  gfx.LoadSkinFont("dmc5font.ttf");
  gfx.BeginPath();
  --[[ gfx.GradientColors(180,51,63,255,217,239,218,255);
  gfx.LinearGradient(480,150,480,550); ]]
  gfx.ImageRect(120,100, 614,181, titleMusicSelectImage, 1, 0)
  gfx.BeginPath();
  end
  gfx.LoadSkinFont("fot-udkakugoc80pro-r.ttf");
  gfx.FontSize(20);
  gfx.FillColor(255,255,255);
  if songwheel.songs[1] ~= nil then
    --draw songwheel and get selected song
    if aspectRatio == "PortraitWidescreen" then
      local song = draw_songwheel(0,0,fullX,fullY,deltaTime)
      --render selected song information
      draw_selected(song, 0,0,fullX,fifthY)
    else
      local song = draw_songwheel(fifthX*2,400,fifthX*3,thirdY*1.2,deltaTime)
      --render selected song information
      draw_selected(song, 1200,230,fifthX*2,(fifthY/2)*9)
    end
  end
  --Draw Legend Information
  if aspectRatio == "PortraitWidescreen" then
    draw_legend(0,(fifthY/3)*14, fullX, (fifthY/3)*1)
  else
    draw_legend(0,(fifthY/2)*9, fullX, (fifthY/2))
  end

  --draw text search
  if aspectRatio == "PortraitWidescreen" then
    draw_search(fifthX*2,5,fifthX*3,fifthY/5)
  else
    draw_search(fifthX*2,5,fifthX*3,fifthY/3)
  end

  ioffset = ioffset * 0.9
  doffset = doffset * 0.9
  soffset = soffset * 0.8
	if songwheel.searchStatus then
		gfx.BeginPath()
		gfx.FillColor(255,255,255)
		gfx.FontSize(20);
		gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP)
		gfx.Text(songwheel.searchStatus, 3, 3)
	end
  gfx.LoadSkinFont("segoeui.ttf");
  gfx.ResetTransform()
  gfx.ForceRender()
end

draw_force = function(x, y, w, h, deltaTime)
  gfx.LoadSkinFont("dmc5fontblock.ttf")
  gfx.BeginPath()
  gfx.FillColor(249, 247, 222)
  gfx.FontSize(h / 3.64)
  gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_BOTTOM)
  local forceText = string.format("%.2f", get_force())
  gfx.Text("TOTAL FORCE", x + w, y)
  gfx.FontSize(h * 2 / 3)
  gfx.Text(forceText, x + w, y + h * 2 / 3)
end

set_index = function(newIndex)
    if newIndex ~= currentSelectedSongIndex then
        game.PlaySample("menu_click")
    end
    ioffset = ioffset + currentSelectedSongIndex - newIndex
    previousSelectedSongIndex = currentSelectedSongIndex
    currentSelectedSongIndex = newIndex
end;

set_diff = function(newDiff)
    if newDiff ~= selectedDiff then
        game.PlaySample("click-02")
    end
    doffset = doffset + selectedDiff - newDiff
    selectedDiff = newDiff
end;

local badgeRates = {
	0.5,  -- Played
	1.0,  -- Cleared
	1.02, -- Hard clear
	1.04, -- UC
	1.1   -- PUC
}

local gradeRates = {
	{["min"] = 9900000, ["rate"] = 1.05}, -- S
	{["min"] = 9800000, ["rate"] = 1.02}, -- AAA+
	{["min"] = 9700000, ["rate"] = 1},    -- AAA
	{["min"] = 9500000, ["rate"] = 0.97}, -- AA+
	{["min"] = 9300000, ["rate"] = 0.94}, -- AA
	{["min"] = 9000000, ["rate"] = 0.91}, -- A+
	{["min"] = 8700000, ["rate"] = 0.88}, -- A
	{["min"] = 7500000, ["rate"] = 0.85}, -- B
	{["min"] = 6500000, ["rate"] = 0.82}, -- C
	{["min"] =       0, ["rate"] = 0.8}   -- D
}

calculate_force = function(diff)
	if #diff.scores < 1 then
		return 0
	end
	local score = diff.scores[1]
	local badgeRate = badgeRates[diff.topBadge]
	local gradeRate
    for i, v in ipairs(gradeRates) do
      if score.score >= v.min then
        gradeRate = v.rate
		break
      end
    end
	return math.floor((diff.level * 2) * (score.score / 10000000) * gradeRate * badgeRate) / 100
end

songs_changed = function(withAll)
	if not withAll then return end
end

get_force = function()	
  local diffs = {}
	for i = 1, #songwheel.allSongs do
		local song = songwheel.allSongs[i]
		for j = 1, #song.difficulties do
			local diff = song.difficulties[j]
			diff.force = calculate_force(diff)
			table.insert(diffs, diff)
		end
	end
	table.sort(diffs, function (l, r)
		return l.force > r.force
	end)
	local totalForce = 0
	for i = 1, 50 do
		if diffs[i] then
			totalForce = totalForce + diffs[i].force
		end
  end
  return totalForce
end