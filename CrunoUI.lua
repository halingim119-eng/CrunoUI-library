local env = (getgenv and getgenv()) or _G
if env.CrunoUI and type(env.CrunoUI.Destroy) == "function" then
    pcall(function() env.CrunoUI:Destroy() end)
end

local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)

local Lib = {
    Version = "1.0.0",
    Flags = {},
    ConfigFolder = "CrunoUI",
    PickerYOffset = 0,
    SidePad = 10,
    ResumeTexts = {"Resume", "계속하기", "재개", "게임으로 돌아가기"},
    Theme = {
        Text = WHITE,
        Row = Color3.fromRGB(38, 40, 45),
        Hover = Color3.fromRGB(46, 48, 54),
        Field = Color3.fromRGB(28, 30, 34),
        Stroke = Color3.fromRGB(62, 64, 72),
        Muted = Color3.fromRGB(165, 168, 176),
        Off = Color3.fromRGB(85, 87, 95),
        Accent = Color3.fromRGB(0, 146, 214),
        AccentDark = Color3.fromRGB(43, 105, 159),
        Bar = Color3.fromRGB(26, 36, 48),
        Danger = Color3.fromRGB(220, 80, 80),
        Avatar = Color3.fromRGB(60, 62, 70),
    },
}
local T = Lib.Theme

local TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function tween(o, props, info) TweenService:Create(o, info or TWEEN, props):Play() end
local function isText(o) return o:IsA("TextLabel") or o:IsA("TextButton") end

local Env
local active
local destroyed = false
local Windows, conns, Controls = {}, {}, {}
local setActive

local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(conns, c)
    return c
end

local function follow(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        node = node and node:FindFirstChild(name)
        if not node then return nil end
    end
    return node
end

local function getRefs()
    local shield = follow(CoreGui, "RobloxGui", "SettingsClippingShield", "SettingsShield")
    local window = shield and shield:FindFirstChild("MenuContainer")
    local tabBar = follow(window, "Page", "HubBar", "TabHeaderContainer", "HubBarContainer")
    local tabButton = tabBar and tabBar:FindFirstChild("GameSettingsTab")
    local content = follow(window, "Page", "PageViewClipper")
    return window, tabBar, tabButton, content
end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if o:IsA("GuiObject") then o.ZIndex = 100 end

    if class == "UIStroke" then o.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
    o.Parent = parent
    return o
end

local function corner(o, r)
    return make("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end

local function fieldStroke(o)
    return make("UIStroke", {Color = T.Stroke, Thickness = 1}, o)
end

local function onClick(obj, fn)
    local found = false
    for _, o in ipairs({obj, table.unpack(obj:GetDescendants())}) do
        if o:IsA("GuiButton") then
            found = true
            o.Activated:Connect(fn)
        end
    end
    if not found then
        obj.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then fn() end
        end)
    end
end

local function httpGet(url)
    local req = (syn and syn.request) or request or http_request or (http and http.request)
    if req then
        local ok, res = pcall(req, {Url = url, Method = "GET"})
        if ok and res and (res.Body or res.body) then return res.Body or res.body end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then return body end
end

local function copy(text)
    local f = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if f then return (pcall(f, text)) end
    return false
end

local function toHex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function fromHex(s)
    local a, b, c = tostring(s):match("#?(%x%x)(%x%x)(%x%x)")
    if a then return Color3.fromRGB(tonumber(a, 16), tonumber(b, 16), tonumber(c, 16)) end
end

local function resolveIndex(options, d)
    if d ~= nil then
        for i, o in ipairs(options) do
            if tostring(o) == tostring(d) then return i end
        end
        if type(d) == "number" and options[d] ~= nil then return d end
    end
    return 1
end

local lucideLib, lucideDone = nil, false
task.spawn(function()
    local src = httpGet("https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau")
    if src then
        local ok, mod = pcall(function() return loadstring(src)() end)
        if ok and type(mod) == "table" and mod.GetAsset then lucideLib = mod end
    end
    lucideDone = true
end)
local function icon(parent, names, props)
    local p = {BackgroundTransparency = 1, ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Fit}
    for k, v in pairs(props or {}) do p[k] = v end
    local img = make("ImageLabel", p, parent)
    task.spawn(function()
        while not lucideDone do task.wait(0.1) end
        if not lucideLib then return end
        for _, n in ipairs(names) do
            local ok, a = pcall(lucideLib.GetAsset, n, 256)
            if ok and a then
                img.Image = a.Url
                img.ImageRectSize = a.ImageRectSize
                img.ImageRectOffset = a.ImageRectOffset
                return
            end
        end
    end)
    return img
end

local function setFlag(o, ...)
    if o.Flag then
        if select("#", ...) > 1 then Lib.Flags[o.Flag] = {...} else Lib.Flags[o.Flag] = (...) end
    end
end
local function emit(o, ...)
    setFlag(o, ...)
    if o.Callback then task.spawn(o.Callback, ...) end
end
local function initEmit(o, ...)
    setFlag(o, ...)
    if o.Callback and not o.Silent then task.spawn(o.Callback, ...) end
end

local function fsOK()
    return writefile and readfile and listfiles and isfolder and makefolder and true or false
end

function Lib:SaveConfig(name)
    if not fsOK() then return false, "filesystem not supported" end
    if not isfolder(self.ConfigFolder) then pcall(makefolder, self.ConfigFolder) end
    local values = {}
    for key, c in pairs(Controls) do
        local ok, v = pcall(c.get)
        if ok then values[key] = v end
    end
    local fileName = (name and tostring(name) or ("config_" .. os.date("%Y%m%d_%H%M%S"))) .. ".json"
    local ok = pcall(writefile, self.ConfigFolder .. "/" .. fileName,
        HttpService:JSONEncode({time = os.time(), values = values}))
    return ok, fileName
end

function Lib:LoadConfig(name)
    if not fsOK() then return false, "filesystem not supported" end
    if not isfolder(self.ConfigFolder) then return false, "none" end
    local fileName
    if name then
        fileName = tostring(name) .. ".json"
    else
        local ok, files = pcall(listfiles, self.ConfigFolder)
        if not ok or type(files) ~= "table" then return false, "none" end
        local names = {}
        for _, f in ipairs(files) do
            local n = tostring(f):match("[^/\\]+$")
            if n and n:match("^config_.+%.json$") then table.insert(names, n) end
        end
        table.sort(names)
        fileName = names[#names]
    end
    if not fileName then return false, "none" end
    local ok, raw = pcall(readfile, self.ConfigFolder .. "/" .. fileName)
    if not ok then return false, "read failed" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" or type(data.values) ~= "table" then return false, "invalid file" end
    for key, v in pairs(data.values) do
        local c = Controls[key]
        if c then pcall(c.set, v) end
    end
    return true, fileName
end

local function isCustom(d)
    local n = d
    while n and (not Env or n ~= Env.menuPanel) do
        if n:GetAttribute("CrunoCustom") then return true end
        n = n.Parent
    end
    return false
end

local function remember(list, obj, prop)
    table.insert(list, {obj, prop, obj[prop]})
    obj[prop] = 1
end

local function hideRealIndicator()
    local e = Env
    if #e.hidden > 0 then return end
    local pW = e.menuPanel.AbsoluteSize.X
    local y0 = e.container.AbsolutePosition.Y - 10
    local y1 = e.container.AbsolutePosition.Y + e.container.AbsoluteSize.Y + 120
    for _, d in ipairs(e.menuPanel:GetDescendants()) do
        if d:IsA("GuiObject") and not isCustom(d) then
            local s, p = d.AbsoluteSize, d.AbsolutePosition
            if s.Y > 0 and s.Y <= 10 and s.X >= 40 and s.X < pW * 0.6 and p.Y >= y0 and p.Y <= y1 then
                if d.BackgroundTransparency < 1 then remember(e.hidden, d, "BackgroundTransparency") end
                if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.ImageTransparency < 1 then
                    remember(e.hidden, d, "ImageTransparency")
                end
                for _, st in ipairs(d:GetChildren()) do
                    if st:IsA("UIStroke") and st.Transparency < 1 then remember(e.hidden, st, "Transparency") end
                end
            end
        end
    end
end

local function restoreList(list)
    for _, h in ipairs(list) do
        if h[1].Parent then h[1][h[2]] = h[3] end
    end
    table.clear(list)
end

local function fadeOne(o)
    local f = Env.faded
    if o:IsA("GuiObject") and o.BackgroundTransparency < 1 then remember(f, o, "BackgroundTransparency") end
    if (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) and o.TextTransparency < 1 then
        remember(f, o, "TextTransparency")
    end
    if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.ImageTransparency < 1 then
        remember(f, o, "ImageTransparency")
    end
    if o:IsA("UIStroke") and o.Transparency < 1 then remember(f, o, "Transparency") end
end

local function hideRealContent()
    local e = Env
    if #e.faded > 0 then return end
    fadeOne(e.content)
    for _, d in ipairs(e.content:GetDescendants()) do fadeOne(d) end
end

local function relayoutTabs()
    local e = Env
    local base = e.baseScale
    if base <= 0 then return end
    local n0 = #e.origTabs
    local total = base * n0
    local custom = {}
    for _, w in ipairs(Windows) do if w.tab then table.insert(custom, w.tab) end end
    local each = total / (n0 + #custom)
    local function apply(c)
        local s = c.Size
        c.Size = UDim2.new(each, s.X.Offset, s.Y.Scale, s.Y.Offset)
    end
    for _, c in ipairs(e.origTabs) do apply(c) end
    for _, c in ipairs(custom) do apply(c) end
end

local function layoutPage(w)
    local e = Env
    local pTop = e.menuPanel.AbsolutePosition.Y
    local pH = e.menuPanel.AbsoluteSize.Y
    local top = e.container.AbsolutePosition.Y + e.container.AbsoluteSize.Y - pTop + 10
    local bottom = 8
    for _, d in ipairs(e.menuPanel:GetDescendants()) do
        if isText(d) and d.AbsoluteSize.Y > 0 and not isCustom(d) and table.find(Lib.ResumeTexts, d.Text) then
            local y = d.AbsolutePosition.Y - pTop
            if y > pH * 0.6 then bottom = pH - y + 24 end
            break
        end
    end
    w.page.Position = UDim2.fromOffset(Lib.SidePad, top)
    w.page.Size = UDim2.new(1, -Lib.SidePad * 2, 1, -(top + bottom))
end

local function paint(w, v)
    w.page.Visible = v
    w.underline.Visible = v
    if w.tabLabel then
        if v then
            w.tabLabel.TextColor3 = w.brightC
            w.tabLabel.TextTransparency = w.brightT
        elseif Env.dimC then
            w.tabLabel.TextColor3 = Env.dimC
            w.tabLabel.TextTransparency = Env.dimT
        end
    end
    if v then
        layoutPage(w)
        w.applyCard()
    end
end

setActive = function(w)
    if not Env or active == w then return end
    local prev = active
    active = w
    if prev then paint(prev, false) end
    if w then
        paint(w, true)
        hideRealIndicator()
        hideRealContent()
        task.delay(0.1, function()
            if active == w and w.page.Visible then layoutPage(w) w.applyCard() end
        end)
    else
        restoreList(Env.hidden)
        restoreList(Env.faded)
    end
end

local function initCore()
    if Env then return true end
    local menuPanel, container, firstTab, content = getRefs()
    if not (menuPanel and container and firstTab and content) then
        return false, {window = menuPanel, tabBar = container, tabButton = firstTab, content = content}
    end
    local e = {menuPanel = menuPanel, container = container, firstTab = firstTab, content = content,
        hidden = {}, faded = {}, origTabs = {}}

    local bestW = -1
    for i, d in ipairs(firstTab:GetDescendants()) do
        if isText(d) and d.AbsoluteSize.X > bestW then bestW = d.AbsoluteSize.X e.best = i end
    end

    for _, c in ipairs(container:GetChildren()) do
        if c ~= firstTab and c:IsA("GuiObject") then
            for _, d in ipairs(c:GetDescendants()) do
                if isText(d) and d.Text ~= "" then e.dimC, e.dimT = d.TextColor3, d.TextTransparency break end
            end
            if e.dimC then break end
        end
    end

    e.baseScale = firstTab.Size.X.Scale
    if e.baseScale > 0 then
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("GuiObject") and math.abs(c.Size.X.Scale - e.baseScale) < 0.001 then
                table.insert(e.origTabs, c)
            end
        end
    end
    Env = e

    for _, c in ipairs(container:GetChildren()) do
        if c:IsA("GuiObject") then onClick(c, function() setActive(nil) end) end
    end
    bind(GuiService.MenuClosed, function() setActive(nil) end)
    return true
end

local sampledH
local ipCache

local function fetchIP()
    if ipCache == nil then
        local body = httpGet("http://ip-api.com/json/?fields=status,country,query&lang=en")
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        ipCache = (ok and data and data.status == "success") and data or false
    end
    return ipCache
end

local function sampleRow()
    local e = Env
    for _, d in ipairs(CoreGui:GetDescendants()) do
        if isText(d) and (d.Text == lp.DisplayName or d.Text == "@" .. lp.Name) and not isCustom(d) then
            local n = d.Parent
            while n and n ~= CoreGui do
                if n:IsA("GuiObject") and n.BackgroundTransparency < 1
                    and n.AbsoluteSize.X > e.menuPanel.AbsoluteSize.X * 0.6
                    and n.AbsoluteSize.Y <= e.menuPanel.AbsoluteSize.Y * 0.25 and n.AbsoluteSize.Y > 0 then
                    return n
                end
                n = n.Parent
            end
        end
    end
end

local function buildProfile(w, scroll, probe, showIP)
    local topRow = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 240), LayoutOrder = -1}, scroll)

    local card = make("Frame", {Size = UDim2.new(0.612, -7, 1, 0), BackgroundColor3 = T.Row, BorderSizePixel = 0}, topRow)
    corner(card, 8)
    local avatar = make("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(120, 120), BackgroundColor3 = T.Avatar, BorderSizePixel = 0}, card)
    corner(avatar, 999)
    local info = make("Frame", {BackgroundTransparency = 1, Position = UDim2.new(0, 150, 0, 10),
        Size = UDim2.new(1, -160, 1, -20)}, card)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, info)
    local labels = {}
    local function infoLabel(order, str)
        local l = make("TextLabel", {BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 1 / 6, 0),
            Text = str, TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, info)
        table.insert(labels, l)
        return l
    end
    infoLabel(1, "Name  " .. lp.Name)
    infoLabel(2, "Display Name  " .. lp.DisplayName)
    infoLabel(3, "Nickname  @" .. lp.Name)
    local teamL = infoLabel(4, "Team  ")
    local ipL = infoLabel(5, showIP and "IP  Loading..." or "IP  Hidden")
    local countryL = infoLabel(6, showIP and "Country  Loading..." or "Country  Hidden")

    local function updTeam()
        local t = lp.Team
        teamL.Text = "Team  " .. (t and t.Name or "None")
    end
    updTeam()
    bind(lp:GetPropertyChangedSignal("Team"), updTeam)

    if showIP then
        task.spawn(function()
            local data = fetchIP()
            if data then
                ipL.Text = "IP  " .. tostring(data.query)
                countryL.Text = "Country  " .. tostring(data.country)
            else
                ipL.Text = "IP  Unavailable"
                countryL.Text = "Country  Unavailable"
            end
        end)
    end

    local gameCard = make("Frame", {Position = UDim2.new(0.612, 7, 0, 0), Size = UDim2.new(0.388, -7, 1, 0),
        BackgroundColor3 = T.Row, BorderSizePixel = 0}, topRow)
    corner(gameCard, 8)
    local thumb = make("Frame", {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(96, 96),
        BackgroundColor3 = T.Avatar, BorderSizePixel = 0}, gameCard)
    corner(thumb, 8)
    local gameName = make("TextLabel", {BackgroundTransparency = 1, Text = "Loading...", TextColor3 = T.Text,
        Font = Enum.Font.GothamBold, TextSize = 17, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center}, gameCard)
    local gInfo = make("Frame", {BackgroundTransparency = 1}, gameCard)
    make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, gInfo)
    local gLabels = {}
    local function gLabel(order, str)
        local l = make("TextLabel", {BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.new(1, 0, 0.25, 0),
            Text = str, TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, gInfo)
        table.insert(gLabels, l)
        return l
    end
    local creatorL = gLabel(1, "Creator  Loading...")
    local playersL = gLabel(2, "Players  ")
    gLabel(3, "Place ID  " .. tostring(game.PlaceId))
    local updatedL = gLabel(4, "Updated  Loading...")

    local function updPlayers()
        playersL.Text = "Players  " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
    end
    updPlayers()
    bind(Players.PlayerAdded, updPlayers)
    bind(Players.PlayerRemoving, function() task.defer(updPlayers) end)

    task.spawn(function()
        local ok, pinfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and type(pinfo) == "table" then
            gameName.Text = tostring(pinfo.Name or game.Name)
            creatorL.Text = "Creator  " .. tostring(pinfo.Creator and pinfo.Creator.Name or "Unknown")
            updatedL.Text = "Updated  " .. tostring(pinfo.Updated or "Unknown"):sub(1, 10)
        else
            gameName.Text = tostring(game.Name)
            creatorL.Text = "Creator  Unavailable"
            updatedL.Text = "Updated  Unavailable"
        end
    end)

    local headshot = make("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = ""}, avatar)
    corner(headshot, 999)
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
        end)
        if ok then headshot.Image = img end
    end)
    icon(thumb, {"gamepad", "gamepad-2"}, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.05, 1.05)})

    return function()
        local ratio = probe.AbsoluteSize.X / 100
        if ratio < 0.1 then ratio = 1 end
        if not sampledH then
            local row = sampleRow()
            if row then sampledH = row.AbsoluteSize.Y / ratio end
        end
        local h = math.max(sampledH and sampledH * 4 or 240, 190)
        topRow.Size = UDim2.new(1, 0, 0, h)

        local a = math.floor(h * 0.7)
        avatar.Size = UDim2.fromOffset(a, a)
        info.Position = UDim2.new(0, a + 32, 0, 10)
        info.Size = UDim2.new(1, -(a + 44), 1, -20)
        local ts = math.clamp(math.floor(h / 6 * 0.5), 13, 22)
        for _, l in ipairs(labels) do l.TextSize = ts end

        local s = math.clamp(math.floor(h * 0.4), 70, 120)
        thumb.Size = UDim2.fromOffset(s, s)
        gameName.Position = UDim2.fromOffset(12 + s + 12, 12)
        gameName.Size = UDim2.new(1, -(12 + s + 24), 0, s)
        gInfo.Position = UDim2.fromOffset(12, 12 + s + 10)
        gInfo.Size = UDim2.new(1, -24, 1, -(12 + s + 20))
        local gts = math.clamp(math.floor((h - (s + 32)) / 4 * 0.55), 11, 16)
        for _, l in ipairs(gLabels) do l.TextSize = gts end
    end
end

local function element(w, name, h)
    local r = make("Frame", {Size = UDim2.new(1, 0, 0, h or 44), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        ClipsDescendants = true, LayoutOrder = w:_order()}, w.scroll)
    corner(r, 8)
    make("UIStroke", {Color = T.Stroke, Thickness = 1, Transparency = 0.45}, r)
    local title = make("TextLabel", {BackgroundTransparency = 1, Text = tostring(name or ""), TextColor3 = T.Text,
        Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(0.42, 0, 0, 44)}, r)
    r.MouseEnter:Connect(function() tween(r, {BackgroundColor3 = T.Hover}, TweenInfo.new(0.15)) end)
    r.MouseLeave:Connect(function() tween(r, {BackgroundColor3 = T.Row}, TweenInfo.new(0.15)) end)
    return r, title
end

local function guiInsetY()
    local sg = Env.menuPanel:FindFirstAncestorWhichIsA("ScreenGui")
    if sg and sg.IgnoreGuiInset then
        local ok, a = pcall(function() return GuiService:GetGuiInset() end)
        if ok and a then return a.Y end
    end
    return 0
end

local function makeDraggable(w, obj, onMove)
    local dragging = false
    local function update(i)
        local ap, as = obj.AbsolutePosition, obj.AbsoluteSize
        if as.X <= 0 or as.Y <= 0 then return end
        local fx = (i.Position.X - ap.X) / as.X
        local fy = (i.Position.Y + guiInsetY() + Lib.PickerYOffset - ap.Y) / as.Y
        onMove(math.clamp(fx, 0, 1), math.clamp(fy, 0, 1))
    end
    obj.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            w.scroll.ScrollingEnabled = false
            update(i)
        end
    end)
    bind(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
    end)
    bind(UserInputService.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            w.scroll.ScrollingEnabled = true
        end
    end)
end

local B = {}

B.Section = function(w, o)
    local l = make("TextLabel", {Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        Text = tostring(o.Name or o.Text or ""), TextColor3 = T.Text, Font = Enum.Font.GothamBold, TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = w:_order()}, w.scroll)
    return {nosave = true, get = function() return l.Text end, set = function(t) l.Text = tostring(t) end}
end

B.Label = function(w, o)
    local r = make("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        LayoutOrder = w:_order()}, w.scroll)
    corner(r, 8)
    make("UIStroke", {Color = T.Stroke, Thickness = 1, Transparency = 0.45}, r)
    local l = make("TextLabel", {BackgroundTransparency = 1, Text = tostring(o.Text or o.Name or ""), TextColor3 = T.Muted,
        Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0)}, r)
    return {nosave = true, get = function() return l.Text end, set = function(t) l.Text = tostring(t) end}
end

B.Toggle = function(w, o)
    local r = element(w, o.Name)
    local on = o.Default and true or false
    local sw = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 22),
        Size = UDim2.fromOffset(44, 24), BackgroundColor3 = on and T.Accent or T.Off, BorderSizePixel = 0}, r)
    corner(sw, 999)
    local knob = make("Frame", {AnchorPoint = Vector2.new(0, 0.5),
        Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(20, 20), BackgroundColor3 = WHITE, BorderSizePixel = 0}, sw)
    corner(knob, 999)
    local function set(v)
        on = v and true or false
        tween(sw, {BackgroundColor3 = on and T.Accent or T.Off})
        tween(knob, {Position = on and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)})
        emit(o, on)
    end
    local hit = make("TextButton", {BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 44)}, r)
    hit.Activated:Connect(function() set(not on) end)
    initEmit(o, on)
    return {get = function() return on end, set = function(v) set(v) end}
end

B.Selector = function(w, o)
    local r = element(w, o.Name)
    local options = o.Options or {}
    local i = resolveIndex(options, o.Default)
    local pill = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.fromOffset(150, 28), BackgroundColor3 = T.Field, BorderSizePixel = 0}, r)
    corner(pill, 6)
    fieldStroke(pill)
    local val = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = tostring(options[i]), TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 13}, pill)
    local function arrowBtn(sym, ax)
        local b = make("TextButton", {AnchorPoint = Vector2.new(ax, 0), Position = UDim2.new(ax, 0, 0, 0),
            Size = UDim2.new(0, 32, 1, 0), BackgroundTransparency = 1, Text = sym, TextColor3 = T.Muted,
            Font = Enum.Font.GothamBold, TextSize = 18}, pill)
        b.MouseEnter:Connect(function() tween(b, {TextColor3 = T.Text}, TweenInfo.new(0.12)) end)
        b.MouseLeave:Connect(function() tween(b, {TextColor3 = T.Muted}, TweenInfo.new(0.12)) end)
        return b
    end
    local function set(n)
        if #options == 0 then return end
        i = (n - 1) % #options + 1
        val.Text = tostring(options[i])
        emit(o, options[i])
    end
    arrowBtn("‹", 0).Activated:Connect(function() set(i - 1) end)
    arrowBtn("›", 1).Activated:Connect(function() set(i + 1) end)
    initEmit(o, options[i])
    return {
        get = function() return options[i] end,
        set = function(v)
            for k, op in ipairs(options) do
                if tostring(op) == tostring(v) then set(k) return end
            end
        end,
    }
end

B.Button = function(w, o)
    local r = element(w, o.Name)
    local base = o.Label or "Run"
    local tag = make("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, 22),
        Size = UDim2.fromOffset(110, 24), BackgroundTransparency = 1, Text = base, TextColor3 = T.Muted,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right}, r)
    local hit = make("TextButton", {BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 0, 44)}, r)
    hit.Activated:Connect(function()
        r.BackgroundColor3 = Color3.fromRGB(62, 66, 76)
        tween(r, {BackgroundColor3 = T.Row}, TweenInfo.new(0.35))
        if not o.Callback then return end
        local ok, res = pcall(o.Callback)
        if not ok then warn("[CrunoUI] Button error:", res) res = false end
        if res ~= nil then
            tag.Text = res and (o.Success or "Done!") or (o.Failure or "Failed")
            tag.TextColor3 = res and T.Accent or T.Danger
            task.delay(1.5, function() tag.Text = base tag.TextColor3 = T.Muted end)
        end
    end)
    return {nosave = true, get = function() return nil end, set = function() end}
end

B.Path = function(w, o)
    local text = o.Text or (o.Instance and o.Instance:GetFullName()) or ""
    local r, title = element(w, o.Name, 66)
    title.Position = UDim2.fromOffset(14, 8)
    title.Size = UDim2.new(1, -28, 0, 18)
    local pathL = make("TextLabel", {BackgroundTransparency = 1, Text = text, TextColor3 = T.Muted, Font = Enum.Font.Gotham,
        TextSize = 11, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 30)}, r)
    local hit = make("TextButton", {BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0)}, r)
    hit.Activated:Connect(function()
        local ok = copy(text)
        pathL.Text = ok and "Copied!" or "Clipboard not supported"
        pathL.TextColor3 = ok and T.Accent or T.Danger
        task.delay(1.5, function() pathL.Text = text pathL.TextColor3 = T.Muted end)
    end)
    return {nosave = true, get = function() return text end, set = function(t)
        text = tostring(t) pathL.Text = text
    end}
end

B.Input = function(w, o)
    local r = element(w, o.Name)
    local numeric = o.Numeric
    local box = make("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.new(0.4, 0, 0, 28), BackgroundColor3 = T.Field, Text = tostring(o.Default or ""),
        PlaceholderText = o.Placeholder or (numeric and "Enter number..." or "Enter text..."),
        PlaceholderColor3 = Color3.fromRGB(120, 122, 130), TextColor3 = T.Text, Font = Enum.Font.Gotham,
        TextSize = 13, ClearTextOnFocus = false, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd}, r)
    corner(box, 6)
    local st = fieldStroke(box)
    local function clean()
        if numeric then box.Text = box.Text:gsub("[^%d%.%-]", "") end
    end
    local function value()
        if numeric then return tonumber(box.Text) or 0 end
        return box.Text
    end
    clean()
    box.Focused:Connect(function() tween(st, {Color = T.Accent}, TweenInfo.new(0.15)) end)
    box.FocusLost:Connect(function()
        tween(st, {Color = T.Stroke}, TweenInfo.new(0.15))
        clean()
        emit(o, value())
    end)
    initEmit(o, value())
    return {
        get = function() return box.Text end,
        set = function(v) box.Text = tostring(v) clean() emit(o, value()) end,
    }
end

B.Slider = function(w, o)
    local r = element(w, o.Name)
    local min, max = o.Min or 0, o.Max or 100
    local inc = o.Increment or 1
    local suffix = o.Suffix or ""
    local function snap(v)
        v = math.floor((v - min) / inc + 0.5) * inc + min
        return math.clamp(tonumber(string.format("%.6g", v)), min, max)
    end
    local value = snap(o.Default or min)
    local bar = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.new(0.5, 0, 0, 28), BackgroundColor3 = T.Bar, BorderSizePixel = 0,
        ClipsDescendants = true, Active = true}, r)
    corner(bar, 6)
    make("UIStroke", {Color = T.AccentDark, Thickness = 1, Transparency = 0.2}, bar)
    local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.AccentDark, BorderSizePixel = 0}, bar)
    corner(fill, 6)
    local valL = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "",
        TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 13}, bar)
    local function frac() return max == min and 0 or (value - min) / (max - min) end
    local function show(animate)
        valL.Text = tostring(value) .. suffix
        if animate then tween(fill, {Size = UDim2.fromScale(frac(), 1)})
        else fill.Size = UDim2.fromScale(frac(), 1) end
    end
    show(false)
    makeDraggable(w, bar, function(fx)
        value = snap(min + (max - min) * fx)
        show(false)
        emit(o, value)
    end)
    initEmit(o, value)
    return {
        get = function() return value end,
        set = function(v)
            v = tonumber(v)
            if not v then return end
            value = snap(v)
            show(true)
            emit(o, value)
        end,
    }
end

B.ColorPicker = function(w, o)
    local r = element(w, o.Name)
    local default = o.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = default:ToHSV()
    local swatch = make("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.fromOffset(48, 26), BackgroundColor3 = default, Text = "", AutoButtonColor = false,
        BorderSizePixel = 0}, r)
    corner(swatch, 6)
    make("UIStroke", {Color = WHITE, Transparency = 0.75, Thickness = 1}, swatch)
    local hexBox = make("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -68, 0, 22),
        Size = UDim2.fromOffset(84, 26), BackgroundColor3 = T.Field, Text = toHex(default), TextColor3 = T.Text,
        Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, BorderSizePixel = 0}, r)
    corner(hexBox, 6)
    local hst = fieldStroke(hexBox)

    local sv = make("Frame", {Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -62, 0, 110),
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Active = true}, r)
    corner(sv, 6)
    local white = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0}, sv)
    corner(white, 6)
    make("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
    local black = make("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0}, sv)
    corner(black, 6)
    make("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
    local svCur = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1, BorderSizePixel = 0}, sv)
    corner(svCur, 999)
    make("UIStroke", {Color = WHITE, Thickness = 2}, svCur)

    local hue = make("Frame", {Position = UDim2.new(1, -38, 0, 54), Size = UDim2.fromOffset(26, 110),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Active = true}, r)
    corner(hue, 6)
    local keys = {}
    for i = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1))) end
    make("UIGradient", {Rotation = 90, Color = ColorSequence.new(keys)}, hue)
    local hueCur = make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 6),
        BackgroundTransparency = 1, BorderSizePixel = 0}, hue)
    corner(hueCur, 3)
    make("UIStroke", {Color = WHITE, Thickness = 2}, hueCur)

    local function refresh(silent)
        local c = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = c
        hexBox.Text = toHex(c)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCur.Position = UDim2.fromScale(s, 1 - v)
        hueCur.Position = UDim2.fromScale(0.5, h)
        if not silent then emit(o, c) end
    end
    refresh(true)
    makeDraggable(w, sv, function(fx, fy) s = fx v = 1 - fy refresh() end)
    makeDraggable(w, hue, function(_, fy) h = math.min(fy, 0.999) refresh() end)

    local function setColor(c)
        h, s, v = c:ToHSV()
        refresh()
    end
    hexBox.Focused:Connect(function() tween(hst, {Color = T.Accent}, TweenInfo.new(0.15)) end)
    hexBox.FocusLost:Connect(function()
        tween(hst, {Color = T.Stroke}, TweenInfo.new(0.15))
        local c = fromHex(hexBox.Text)
        if c then setColor(c) else refresh(true) end
    end)

    local open = false
    swatch.Activated:Connect(function()
        open = not open
        tween(r, {Size = UDim2.new(1, 0, 0, open and 176 or 44)})
    end)
    initEmit(o, Color3.fromHSV(h, s, v))
    return {
        get = function() return toHex(Color3.fromHSV(h, s, v)) end,
        set = function(x)
            local c = typeof(x) == "Color3" and x or fromHex(x)
            if c then setColor(c) end
        end,
    }
end

B.Dropdown = function(w, o)
    local r = element(w, o.Name)
    local options = o.Options or {}
    local current = options[resolveIndex(options, o.Default)]
    local head = make("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.fromOffset(160, 28), BackgroundColor3 = T.Field, Text = "", AutoButtonColor = false,
        BorderSizePixel = 0}, r)
    corner(head, 6)
    fieldStroke(head)
    local headL = make("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0), Text = tostring(current), TextColor3 = T.Text, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, head)
    local chev = icon(head, {"chevron-down"}, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), ImageColor3 = T.Muted})
    local open = false
    local btns = {}
    local function setOpen(x)
        open = x
        tween(r, {Size = UDim2.new(1, 0, 0, x and (44 + #options * 32 + 8) or 44)})
        tween(chev, {Rotation = x and 180 or 0})
    end
    local function mark()
        for op, b in pairs(btns) do
            tween(b, {BackgroundColor3 = (op == current) and T.AccentDark or T.Field}, TweenInfo.new(0.15))
        end
    end
    local function choose(op)
        current = op
        headL.Text = tostring(op)
        mark()
        setOpen(false)
        emit(o, op)
    end
    for k, op in ipairs(options) do
        local b = make("TextButton", {Position = UDim2.fromOffset(12, 48 + (k - 1) * 32),
            Size = UDim2.new(1, -24, 0, 28), BackgroundColor3 = (op == current) and T.AccentDark or T.Field,
            Text = tostring(op), TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
            AutoButtonColor = false, BorderSizePixel = 0}, r)
        corner(b, 6)
        btns[op] = b
        b.MouseEnter:Connect(function()
            if op ~= current then tween(b, {BackgroundColor3 = Color3.fromRGB(42, 45, 52)}, TweenInfo.new(0.12)) end
        end)
        b.MouseLeave:Connect(function()
            if op ~= current then tween(b, {BackgroundColor3 = T.Field}, TweenInfo.new(0.12)) end
        end)
        b.Activated:Connect(function() choose(op) end)
    end
    head.Activated:Connect(function() setOpen(not open) end)
    initEmit(o, current)
    return {
        get = function() return current end,
        set = function(x)
            for _, op in ipairs(options) do
                if tostring(op) == tostring(x) then choose(op) return end
            end
        end,
    }
end

B.MultiDropdown = function(w, o)
    local r = element(w, o.Name)
    local options = o.Options or {}
    local sel = {}
    for _, op in ipairs(o.Default or {}) do sel[op] = true end
    local head = make("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.fromOffset(170, 28), BackgroundColor3 = T.Field, Text = "", AutoButtonColor = false,
        BorderSizePixel = 0}, r)
    corner(head, 6)
    fieldStroke(head)
    local headL = make("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -34, 1, 0), Text = "", TextColor3 = T.Text, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, head)
    local chev = icon(head, {"chevron-down"}, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), ImageColor3 = T.Muted})
    local function result()
        local t = {}
        for _, op in ipairs(options) do if sel[op] then table.insert(t, op) end end
        return t
    end
    local boxes = {}
    local function refresh(silent)
        local t = result()
        headL.Text = #t == 0 and "None" or (#t <= 2 and table.concat(t, ", ") or (#t .. " selected"))
        for op, bx in pairs(boxes) do
            tween(bx, {BackgroundColor3 = sel[op] and T.Accent or T.Off}, TweenInfo.new(0.15))
        end
        if not silent then emit(o, t) end
    end
    local open = false
    head.Activated:Connect(function()
        open = not open
        tween(r, {Size = UDim2.new(1, 0, 0, open and (44 + #options * 32 + 8) or 44)})
        tween(chev, {Rotation = open and 180 or 0})
    end)
    for k, op in ipairs(options) do
        local b = make("TextButton", {Position = UDim2.fromOffset(12, 48 + (k - 1) * 32),
            Size = UDim2.new(1, -24, 0, 28), BackgroundColor3 = T.Field, Text = "", AutoButtonColor = false,
            BorderSizePixel = 0}, r)
        corner(b, 6)
        local bx = make("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.Off, BorderSizePixel = 0}, b)
        corner(bx, 4)
        boxes[op] = bx
        make("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0),
            Size = UDim2.new(1, -40, 1, 0), Text = tostring(op), TextColor3 = T.Text, Font = Enum.Font.GothamMedium,
            TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, b)
        b.Activated:Connect(function() sel[op] = not sel[op] or nil refresh() end)
    end
    refresh(true)
    initEmit(o, result())
    return {
        get = result,
        set = function(list)
            if type(list) ~= "table" then return end
            sel = {}
            for _, op in ipairs(list) do sel[op] = true end
            refresh()
        end,
    }
end

B.Keybind = function(w, o)
    local r = element(w, o.Name)
    local d = o.Default
    if type(d) == "string" then
        local ok, k = pcall(function() return Enum.KeyCode[d] end)
        d = ok and k or nil
    end
    local key = d or Enum.KeyCode.Unknown
    local waiting = false
    local btn = make("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.fromOffset(110, 28), BackgroundColor3 = T.Field, Text = key.Name, TextColor3 = T.Text,
        Font = Enum.Font.GothamMedium, TextSize = 13, AutoButtonColor = false, BorderSizePixel = 0}, r)
    corner(btn, 6)
    local st = fieldStroke(btn)
    local function idle()
        waiting = false
        btn.Text = key.Name
        tween(st, {Color = T.Stroke}, TweenInfo.new(0.15))
    end
    btn.Activated:Connect(function()
        waiting = true
        btn.Text = "Press a key..."
        tween(st, {Color = T.Accent}, TweenInfo.new(0.15))
    end)
    bind(UserInputService.InputBegan, function(i, gp)
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if waiting then
            if i.KeyCode == Enum.KeyCode.Backspace then key = Enum.KeyCode.Unknown
            elseif i.KeyCode ~= Enum.KeyCode.Escape then key = i.KeyCode end
            idle()
            setFlag(o, key)
        elseif i.KeyCode == key and key ~= Enum.KeyCode.Unknown and not gp then
            if o.Callback then task.spawn(o.Callback, key) end
        end
    end)
    setFlag(o, key)
    return {
        get = function() return key.Name end,
        set = function(x)
            local ok, k = pcall(function() return Enum.KeyCode[tostring(x)] end)
            if ok and k then key = k idle() setFlag(o, key) end
        end,
    }
end

B.Palette = function(w, o)
    local colors = o.Colors or {}
    local cols, sz, gap = 8, 28, 8
    local rows = math.ceil(#colors / cols)
    local r = element(w, o.Name, 44 + rows * (sz + gap) + 4)
    local cur = 1
    if typeof(o.Default) == "Color3" then
        for i, c in ipairs(colors) do if toHex(c) == toHex(o.Default) then cur = i break end end
    elseif type(o.Default) == "number" and colors[o.Default] then
        cur = o.Default
    end
    local items = {}
    local function mark()
        for i, it in ipairs(items) do
            tween(it.st, {Transparency = (i == cur) and 0 or 1}, TweenInfo.new(0.15))
        end
    end
    for i, c in ipairs(colors) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local b = make("TextButton", {Position = UDim2.fromOffset(14 + col * (sz + gap), 48 + row * (sz + gap)),
            Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = c, Text = "", AutoButtonColor = false,
            BorderSizePixel = 0}, r)
        corner(b, 6)
        local st = make("UIStroke", {Color = WHITE, Thickness = 2, Transparency = (i == cur) and 0 or 1}, b)
        items[i] = {b = b, st = st}
        b.Activated:Connect(function() cur = i mark() emit(o, c) end)
    end
    if colors[cur] then initEmit(o, colors[cur]) end
    return {
        get = function() return colors[cur] and toHex(colors[cur]) or nil end,
        set = function(x)
            for i, c in ipairs(colors) do
                local hex = typeof(x) == "Color3" and toHex(x) or tostring(x):upper()
                if toHex(c) == hex then cur = i mark() emit(o, c) return end
            end
        end,
    }
end

B.Range = function(w, o)
    local r = element(w, o.Name)
    local min, max = o.Min or 0, o.Max or 100
    local suffix = o.Suffix or ""
    local lo = math.clamp(o.DefaultMin or min, min, max)
    local hi = math.clamp(o.DefaultMax or max, min, max)
    local bar = make("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 22),
        Size = UDim2.new(0.5, 0, 0, 28), BackgroundColor3 = T.Bar, BorderSizePixel = 0,
        ClipsDescendants = true, Active = true}, r)
    corner(bar, 6)
    make("UIStroke", {Color = T.AccentDark, Thickness = 1, Transparency = 0.2}, bar)
    local fill = make("Frame", {BackgroundColor3 = T.AccentDark, BorderSizePixel = 0}, bar)
    local valL = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "",
        TextColor3 = T.Text, Font = Enum.Font.GothamMedium, TextSize = 13}, bar)
    local function render()
        local span = math.max(max - min, 1)
        local a, b = (lo - min) / span, (hi - min) / span
        fill.Position = UDim2.fromScale(a, 0)
        fill.Size = UDim2.fromScale(b - a, 1)
        valL.Text = lo .. " - " .. hi .. suffix
    end
    render()
    local lock
    makeDraggable(w, bar, function(fx)
        local v = math.floor(min + (max - min) * fx + 0.5)
        if not lock then
            if lo == hi then lock = v < lo and "lo" or "hi"
            else lock = (math.abs(v - lo) <= math.abs(v - hi)) and "lo" or "hi" end
        end
        if lock == "lo" then lo = math.min(v, hi) else hi = math.max(v, lo) end
        render()
        emit(o, lo, hi)
    end)
    bind(UserInputService.InputEnded, function() lock = nil end)
    initEmit(o, lo, hi)
    return {
        get = function() return {lo, hi} end,
        set = function(a, b)
            if type(a) == "table" then a, b = a[1], a[2] end
            a, b = tonumber(a), tonumber(b)
            if not (a and b) then return end
            lo = math.clamp(math.floor(math.min(a, b) + 0.5), min, max)
            hi = math.clamp(math.floor(math.max(a, b) + 0.5), min, max)
            render()
            emit(o, lo, hi)
        end,
    }
end

local Handle = {}
Handle.__index = Handle
function Handle:Set(...)
    if self._c then self._c.set(...) else self._pending = table.pack(...) end
end
function Handle:Get()
    if self._c then return self._c.get() end
end

local Window = {}
Window.__index = Window

function Window:_order()
    self._n += 1
    return self._n
end

local function defer(w, fn)
    if w.Built then
        local ok, err = pcall(fn)
        if not ok then warn("[CrunoUI]", err) end
    else
        table.insert(w.Queue, fn)
    end
end

local KINDS = {"Section", "Label", "Toggle", "Selector", "Button", "Path", "Input", "Slider",
    "ColorPicker", "Dropdown", "MultiDropdown", "Keybind", "Palette", "Range"}

for _, kind in ipairs(KINDS) do
    Window["Add" .. kind] = function(self, o)
        if type(o) == "string" then o = {Name = o} end
        o = o or {}
        local h = setmetatable({}, Handle)
        defer(self, function()
            local c = B[kind](self, o)
            if not c then return end
            h._c = c
            if not c.nosave and o.Name ~= nil then Controls[self.Name .. "/" .. tostring(o.Name)] = c end
            if h._pending then c.set(table.unpack(h._pending, 1, h._pending.n)) h._pending = nil end
        end)
        return h
    end
end

function Window:Show() if self.Built then setActive(self) end end
function Window:Close() if active == self then setActive(nil) end end

local function buildWindow(w)
    local e = Env
    local tab = e.firstTab:Clone()
    tab.Name = "CustomTab"
    tab:SetAttribute("CrunoCustom", true)
    tab.LayoutOrder = 999 + w.Index

    local tabLabel
    for i, d in ipairs(tab:GetDescendants()) do
        if isText(d) then
            if i == e.best then d.Text = w.Name tabLabel = d else d.Text = "" end
        end
        if d:IsA("ImageLabel") or d:IsA("ImageButton") then d.ImageTransparency = 1 end
    end
    if tabLabel then
        w.brightC, w.brightT = tabLabel.TextColor3, tabLabel.TextTransparency
        if e.dimC then tabLabel.TextColor3 = e.dimC tabLabel.TextTransparency = e.dimT end
    end
    w.tabLabel = tabLabel
    tab.Parent = e.container
    w.tab = tab
    relayoutTabs()

    local page = make("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Active = true}, e.menuPanel)
    page:SetAttribute("CrunoCustom", true)
    local probe = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 100)}, page)
    local scroll = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()}, page)
    make("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
    make("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 12)}, scroll)
    w.page, w.scroll = page, scroll

    w.underline = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, Visible = false}, tab)
    task.delay(0.3, function()
        if not tab.Parent then return end
        for _, d in ipairs(tab:GetDescendants()) do
            if d:IsA("Frame") and d ~= w.underline and d.AbsoluteSize.Y > 0 and d.AbsoluteSize.Y <= 10 then
                d:Destroy()
            end
        end
    end)

    if w.Opts.ShowProfile == false then
        w.applyCard = function() end
    else
        w.applyCard = buildProfile(w, scroll, probe, w.Opts.ShowIP ~= false)
    end

    onClick(tab, function()
        if active == w then setActive(nil) else setActive(w) end
    end)

    w.Built = true
    for _, fn in ipairs(w.Queue) do
        local ok, err = pcall(fn)
        if not ok then warn("[CrunoUI]", err) end
    end
    table.clear(w.Queue)
end

local injectorStarted = false
local function startInjector()
    if injectorStarted then return end
    injectorStarted = true
    task.spawn(function()
        local fails = 0
        while not destroyed do
            if Env or GuiService.MenuIsOpen then
                if not Env then
                    local ok, missing = initCore()
                    if not ok then
                        fails += 1
                        if fails == 5 then
                            warn("[CrunoUI] ESC 메뉴 경로를 못 찾음:")
                            for k, v in pairs(missing or {}) do warn(k, v and "OK" or "MISSING") end
                        end
                    end
                end
                if Env then
                    for _, w in ipairs(Windows) do
                        if not w.Built and not w.Building then
                            w.Building = true
                            local ok, err = pcall(buildWindow, w)
                            if not ok then warn("[CrunoUI] 창 생성 실패:", err) end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

function Lib:AddWindow(opts)
    if type(opts) == "string" then opts = {Name = opts} end
    opts = opts or {}
    local w = setmetatable({
        Name = tostring(opts.Name or "Tab"),
        Opts = opts,
        Queue = {},
        Built = false,
        Index = #Windows + 1,
        _n = 10,
    }, Window)
    table.insert(Windows, w)
    startInjector()
    return w
end

function Lib:WaitReady()
    while not destroyed do
        local all = Env ~= nil and #Windows > 0
        if all then
            for _, w in ipairs(Windows) do
                if not w.Built then all = false break end
            end
        end
        if all then return true end
        task.wait(0.2)
    end
    return false
end

function Lib:Destroy()
    destroyed = true
    pcall(setActive, nil)
    local list = table.clone(Windows)
    table.clear(Windows)
    for _, w in ipairs(list) do
        if w.tab then pcall(function() w.tab:Destroy() end) end
        if w.page then pcall(function() w.page:Destroy() end) end
    end
    if Env then pcall(relayoutTabs) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    table.clear(Controls)
    table.clear(Lib.Flags)
    if env.CrunoUI == Lib then env.CrunoUI = nil end
end

env.CrunoUI = Lib
return Lib
