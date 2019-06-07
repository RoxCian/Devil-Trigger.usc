local mposx = 0;
local mposy = 0;
local hovered = nil;
local buttonWidth = 99999;
local buttonHeight = 50;
local flashingLevel = 0.0;
local flashingPeriod = 1.6; 
local label = -1;
gfx.GradientColors(0,128,255,255,0,128,255,0)
local gradient = gfx.LinearGradient(0,0,0,1)
color = {r = 0;g = 0;b = 0;a = 0;}
function color:new(red,green,blue,alpha)
    c=color
    setmetatable(c,self)
    self.r=red
    self.g=green
    self.b=blue
    self.a=alpha
    return c
end;

view_update = function()
    if package.config:sub(1,1) == '\\' then --windows
        updateUrl, updateVersion = game.UpdateAvailable()
        os.execute("start " .. updateUrl)
    else --unix
        --TODO: Mac solution
        os.execute("xdg-open " .. updateUrl)
    end
end

mouse_clipped = function(x,y,w,h)
    return mposx > x and mposy > y and mposx < x+w and mposy < y+h;
end;

draw_button = function(name, x, y,textX,textY, hoverindex)
    local rx = x - (buttonWidth / 2);
    local ty = y - (buttonHeight / 2);
    gfx.BeginPath();
    if mouse_clipped(rx,ty, buttonWidth, buttonHeight) then
       gfx.LoadSkinFont("dmc5font.ttf");
       hovered = hoverindex;
       gfx.FillColor(0,72,100,math.floor(160+95*math.abs(flashingLevel-0.5)));
       gfx.Rect(rx, ty, buttonWidth, buttonHeight);
       gfx.Fill();  
       draw_text(name,textX,textY,gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE,54,color:new(125,237,247,255));
    else
       gfx.LoadSkinFont("dmc5fontblock.ttf");
       gfx.BeginPath();
       gfx.FillColor(0,0,0,0);
       gfx.Rect(rx, ty, buttonWidth, buttonHeight);
       gfx.Fill();   
       draw_text(name,textX,textY,gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE,50,color:new(186,186,186,255));
    end
end;

draw_text = function(name,x,y,textAlign,fontSize,fontColor)
    gfx.BeginPath();
    gfx.FillColor(fontColor.r,fontColor.g,fontColor.b,fontColor.a);
    gfx.TextAlign(textAlign);
    gfx.FontSize(fontSize);
    gfx.Text(name, x, y);   
end;

render = function(deltaTime)
    resx,resy = game.GetResolution();
    mposx,mposy = game.GetMousePos();
    gfx.Scale(resx, resy / 3)
    gfx.Rect(0,0,1,1)
    gfx.FillPaint(gradient)
    gfx.Fill()
    gfx.ResetTransform()
    gfx.BeginPath()
    buttonY = 2.7 * resy / 4;
    hovered = nil;
    draw_button("START", resx / 2, buttonY, resx / 2  , buttonY,  Menu.Start);
    buttonY = buttonY + 65;
    draw_button("OPTIONS", resx / 2, buttonY, resx / 2, buttonY, Menu.Settings);
    buttonY = buttonY + 65;
    draw_button("GET SONGS BETA", resx / 2, buttonY, resx / 2, buttonY, Menu.DLScreen);
    buttonY = buttonY + 65;
    draw_button("EXIT", resx / 2, buttonY, resx / 2, buttonY, Menu.Exit);
    gfx.BeginPath();
    gfx.FillColor(255,255,255);
    gfx.FontSize(120);
    if label == -1 then
        gfx.LoadSkinFont("dmc5font.ttf");
        label = gfx.CreateLabel("UNNAMED  SDVX  CLONE", 120, 0);
    end
    gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE);
    gfx.DrawLabel(label, resx / 2, resy / 2 - 100, resx-40);
    updateUrl, updateVersion = game.UpdateAvailable()
    if updateUrl then
       gfx.BeginPath()
       gfx.TextAlign(gfx.TEXT_ALIGN_BOTTOM + gfx.TEXT_ALIGN_LEFT)
       gfx.FontSize(30)
       gfx.Text(string.format("Version %s is now available", updateVersion), 5, resy - buttonHeight - 10)
       draw_button("View", buttonWidth / 2 + 5, resy - buttonHeight / 2 - 5, 40, resy - buttonHeight / 2 - 5, view_update);
    end
    local t = 0.0;
    t, flashingLevel = math.modf((flashingLevel * flashingPeriod + deltaTime) / flashingPeriod );
end;

mouse_pressed = function(button)
    if hovered then
        hovered()
    end
    return 0
end
