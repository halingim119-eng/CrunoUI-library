local env = (getgenv and getgenv()) or _G
if env.CrunoUI and type(env.CrunoUI.Destroy) == "function" then
    pcall(function() env.CrunoUI:Destroy() end)
end

local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)

-- 스레드 권한 (지원하는 익스큐터만)
local setIdentity = setthreadidentity or set_thread_identity or setidentity
    or (syn and syn.set_thread_identity)
local getIdentity = getthreadidentity or get_thread_identity or getidentity
    or (syn and syn.get_thread_identity)
local function elevate()
    if not setIdentity then return end
    if not pcall(setIdentity, 8) then pcall(setIdentity, 7) end
end
local function identityStr()
    if not getIdentity then return "n/a" end
    local ok, v = pcall(getIdentity)
    return ok and tostring(v) or "err"
end
elevate()

local Lib = {
    Version = "1.2.9",
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

-- 에러 안 나게 보호: 멤버 접근 자체를 pcall 안에서 수행.
-- CoreGui 접근이 막히면 권한을 올리고 한 번 재시도.
local function follow(root, ...)
    local node = root
    for _, name in ipairs({...}) do
        if not node then return nil end
        local cur = node
        local ok, nxt = pcall(function() return cur:FindFirstChild(name) end)
        if not ok and cur == CoreGui then
            elevate()
            ok, nxt = pcall(function() return cur:FindFirstChild(name) end)
        end
        if not ok then return nil end
        node = nxt
    end
    return node
end

local function getRefs()
    local shield = follow(CoreGui, "RobloxGui", "SettingsClippingShield", "SettingsShield")
    local window = shield and follow(shield, "MenuContainer")
    local tabBar = follow(window, "Page", "HubBar", "TabHeaderContainer", "HubBarContainer")
    local tabButton = tabBar and follow(tabBar, "GameSettingsTab")
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

local iconTokens = setmetatable({}, {__mode = "k"})

local function applyIcon(img, names)
    if type(names) == "number" then names = {"rbxassetid://" .. names} end
    if type(names) == "string" then names = {names} end
    if type(names) ~= "table" then return end

    local token = (iconTokens[img] or 0) + 1
    iconTokens[img] = token

    local first = names[1]
    if type(first) == "string" and first:find("^rbxasset") then
        img.Image = first
        img.ImageRectSize = Vector2.zero
        img.ImageRectOffset = Vector2.zero
        return
    end

    task.spawn(function()
        while not lucideDone do task.wait(0.1) end
        if not lucideLib or iconTokens[img] ~= token then return end
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
end

local function icon(parent, names, props)
    local p = {BackgroundTransparency = 1, ImageColor3 = WHITE, ScaleType = Enum.ScaleType.Fit}
    for k, v in pairs(props or {}) do p[k] = v end
    local img = make("ImageLabel", p, parent)
    applyIcon(img, names)
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

local function newHold()
    return {recs = {}, map = setmetatable({}, {__mode = "k"})}
end

local function hold(list, obj, prop)
    local per = list.map[obj]
    if not per then
        per = {}
        list.map[obj] = per
    end
    if per[prop] then return end
    local rec = {obj = obj, prop = prop, orig = obj[prop], released = false}
    per[prop] = rec
    table.insert(list.recs, rec)
    obj[prop] = 1
    rec.conn = obj:GetPropertyChangedSignal(prop):Connect(function()
        if rec.released then return end
        local cur = obj[prop]
        if cur ~= 1 then
            rec.orig = cur
            obj[prop] = 1
        end
    end)
end

local function releaseAll(list)
    for _, rec in ipairs(list.recs) do
        rec.released = true
        if rec.conn then rec.conn:Disconnect() end
        if rec.obj.Parent then
            pcall(function() rec.obj[rec.prop] = rec.orig end)
        end
    end
    list.recs = {}
    list.map = setmetatable({}, {__mode = "k"})
end

local function holdObject(list, o)
    if o:IsA("GuiObject") then hold(list, o, "BackgroundTransparency") end
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        hold(list, o, "TextTransparency")
        hold(list, o, "TextStrokeTransparency")
    end
    if o:IsA("ImageLabel") or o:IsA("ImageButton") then hold(list, o, "ImageTransparency") end
    if o:IsA("ScrollingFrame") then hold(list, o, "ScrollBarImageTransparency") end
    if o:IsA("CanvasGroup") then hold(list, o, "GroupTransparency") end
    if o:IsA("UIStroke") then hold(list, o, "Transparency") end
end

local function hideRealContent()
    local e = Env
    holdObject(e.faded, e.content)
    for _, d in ipairs(e.content:GetDescendants()) do holdObject(e.faded, d) end
end

local function hideRealIndicator()
    local e = Env
    local pW = e.menuPanel.AbsoluteSize.X
    local y0 = e.container.AbsolutePosition.Y - 10
    local y1 = e.container.AbsolutePosition.Y + e.container.AbsoluteSize.Y + 120
    for _, d in ipairs(e.menuPanel:GetDescendants()) do
        if d:IsA("GuiObject") then
            local s, p = d.AbsoluteSize, d.AbsolutePosition
            if s.Y > 0 and s.Y <= 10 and s.X >= 40 and s.X < pW * 0.6 and p.Y >= y0 and p.Y <= y1
                and not isCustom(d) then
                hold(e.hidden, d, "BackgroundTransparency")
                if d:IsA("ImageLabel") or d:IsA("ImageButton") then hold(e.hidden, d, "ImageTransparency") end
                for _, st in ipairs(d:GetChildren()) do
                    if st:IsA("UIStroke") then hold(e.hidden, st, "Transparency") end
                end
            end
        end
    end
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

local function layoutSig()
    local e = Env
    local a, b = e.menuPanel.AbsolutePosition, e.menuPanel.AbsoluteSize
    local c, d = e.container.AbsolutePosition, e.container.AbsoluteSize
    return string.format("%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f", a.X, a.Y, b.X, b.Y, c.X, c.Y, d.X, d.Y)
end

local watchToken = 0
local function watch(w)
    watchToken += 1
    local my = watchToken
    task.spawn(function()
        local lastSig = layoutSig()
        local lastSweep = os.clock()
        while not destroyed and active == w and watchToken == my and Env do
            task.wait(0.05)
            if active ~= w or watchToken ~= my then break end
            local sig = layoutSig()
            if sig ~= lastSig then
                lastSig = sig
                if w.page.Visible then
                    layoutPage(w)
                    w.applyCard()
                end
            end
            if os.clock() - lastSweep >= 0.4 then
                lastSweep = os.clock()
                hideRealContent()
                hideRealIndicator()
            end
        end
    end)
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
        watch(w)
    else
        watchToken += 1
        releaseAll(Env.hidden)
        releaseAll(Env.faded)
    end
end

local function reveal(w)
    if active == w then
        paint(w, true)
        hideRealIndicator()
        hideRealContent()
        watch(w)
    else
        setActive(w)
    end
end

local function initCore()
    if Env then return true end
    local menuPanel, container, firstTab, content = getRefs()
    if not (menuPanel and container and firstTab and content) then
        return false, {window = menuPanel, tabBar = container, tabButton = firstTab, content = content}
    end
    if menuPanel.AbsoluteSize.Y <= 0 or container.AbsoluteSize.Y <= 0 or firstTab.AbsoluteSize.X <= 0 then
        return false, {layout = false}
    end
    local e = {menuPanel = menuPanel, container = container, firstTab = firstTab, content = content,
        hidden = newHold(), faded = newHold(), origTabs = {}}

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
    bind(content.DescendantAdded, function(d)
        if active and Env then holdObject(Env.faded, d) end
    end)
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
    local root = follow(CoreGui, "RobloxGui") or CoreGui
    local ok, list = pcall(function() return root:GetDescendants() end)
    if not ok then
        elevate()
        ok, list = pcall(function() return root:GetDescendants() end)
    end
    if not ok then return nil end
    for _, d in ipairs(list) do
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

local function extend(r, title, c)
    c.root = r
    c.setText = function(t) title.Text = tostring(t) end
    return c
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
    local function setText(t) l.Text = tostring(t) end
    return {nosave = true, root = l, get = function() return l.Text end, set = setText, setText = setText}
end

B.Label = function(w, o)
    local ts = tonumber(o.TextSize) or 13
    local lines = math.max(1, math.floor(tonumber(o.Lines) or 1))
    local iconSize = 18

    local r = make("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Row, BorderSizePixel = 0,
        LayoutOrder = w:_order()}, w.scroll)
    corner(r, 8)
    make("UIStroke", {Color = T.Stroke, Thickness = 1, Transparency = 0.45}, r)

    local align = Enum.TextXAlignment.Left
    if o.Align then
        local ok, a = pcall(function() return Enum.TextXAlignment[o.Align] end)
        if ok and a then align = a end
    end
    local l = make("TextLabel", {BackgroundTransparency = 1, Text = tostring(o.Text or o.Name or ""),
        TextColor3 = o.Color or T.Muted, Font = o.Font or Enum.Font.Gotham, TextSize = ts,
        TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = align, TextYAlignment = Enum.TextYAlignment.Center}, r)

    local img
    local function layout()
        local lineH = math.ceil(ts * 1.25)
        r.Size = UDim2.new(1, 0, 0, math.max(36, lines * lineH + 16))
        local left = 14
        if img and img.Visible then
            img.Position = UDim2.new(0, 14, 0.5, 0)
            left = 14 + iconSize + 8
        end
        l.Position = UDim2.fromOffset(left, 0)
        l.Size = UDim2.new(1, -(left + 14), 1, 0)
        l.TextSize = ts
    end

    local function setIcon(name)
        if name == nil or name == false or name == "" then
            if img then img.Visible = false end
        else
            if not img then
                img = make("ImageLabel", {AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(iconSize, iconSize),
                    BackgroundTransparency = 1, ImageColor3 = o.IconColor or WHITE, ScaleType = Enum.ScaleType.Fit}, r)
            end
            img.Visible = true
            applyIcon(img, name)
        end
        layout()
    end

    if o.Icon then setIcon(o.Icon) else layout() end

    local function setText(t) l.Text = tostring(t) end
    return {
        nosave = true,
        root = r,
        get = function() return l.Text end,
        set = setText,
        setText = setText,
        setLines = function(n)
            lines = math.max(1, math.floor(tonumber(n) or 1))
            layout()
        end,
        setIcon = setIcon,
        setColor = function(c) if typeof(c) == "Color3" then l.TextColor3 = c end end,
        setIconColor = function(c) if img and typeof(c) == "Color3" then img.ImageColor3 = c end end,
        setTextSize = function(n)
            ts = tonumber(n) or ts
            layout()
        end,
    }
end

B.Toggle = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {get = function() return on end, set = function(v) set(v) end})
end

B.Selector = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = function() return options[i] end,
        set = function(v)
            for k, op in ipairs(options) do
                if tostring(op) == tostring(v) then set(k) return end
            end
        end,
    })
end

B.Button = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        nosave = true,
        get = function() return nil end,
        set = function() end,
        setLabel = function(t)
            base = tostring(t)
            tag.Text = base
        end,
    })
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
    return extend(r, title, {nosave = true, get = function() return text end, set = function(t)
        text = tostring(t) pathL.Text = text
    end})
end

B.Input = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = function() return box.Text end,
        set = function(v) box.Text = tostring(v) clean() emit(o, value()) end,
        setPlaceholder = function(t) box.PlaceholderText = tostring(t) end,
    })
end

B.Slider = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = function() return value end,
        set = function(v)
            v = tonumber(v)
            if not v then return end
            value = snap(v)
            show(true)
            emit(o, value)
        end,
    })
end

B.ColorPicker = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = function() return toHex(Color3.fromHSV(h, s, v)) end,
        set = function(x)
            local c = typeof(x) == "Color3" and x or fromHex(x)
            if c then setColor(c) end
        end,
    })
end

B.Dropdown = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = function() return current end,
        set = function(x)
            for _, op in ipairs(options) do
                if tostring(op) == tostring(x) then choose(op) return end
            end
        end,
    })
end

B.MultiDropdown = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = result,
        set = function(list)
            if type(list) ~= "table" then return end
            sel = {}
            for _, op in ipairs(list) do sel[op] = true end
            refresh()
        end,
    })
end

B.Keybind = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
        get = function() return key.Name end,
        set = function(x)
            local ok, k = pcall(function() return Enum.KeyCode[tostring(x)] end)
            if ok and k then key = k idle() setFlag(o, key) end
        end,
    })
end

B.Palette = function(w, o)
    local colors = o.Colors or {}
    local cols, sz, gap = 8, 28, 8
    local rows = math.ceil(#colors / cols)
    local r, title = element(w, o.Name, 44 + rows * (sz + gap) + 4)
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
    return extend(r, title, {
        get = function() return colors[cur] and toHex(colors[cur]) or nil end,
        set = function(x)
            for i, c in ipairs(colors) do
                local hex = typeof(x) == "Color3" and toHex(x) or tostring(x):upper()
                if toHex(c) == hex then cur = i mark() emit(o, c) return end
            end
        end,
    })
end

B.Range = function(w, o)
    local r, title = element(w, o.Name)
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
    return extend(r, title, {
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
    })
end

local Handle = {}
Handle.__index = Handle

local PROXY = {
    Set = "set",
    SetValue = "setValue",
    SetSilent = "setSilent",
    SetText = "setText",
    SetInputValue = "setInputValue",
    SetPlaceholder = "setPlaceholder",
    SetLabel = "setLabel",
    SetIcon = "setIcon",
    SetIconColor = "setIconColor",
    SetLines = "setLines",
    SetColor = "setColor",
    SetTextSize = "setTextSize",
    SetVisible = "setVisible",
}
for method, field in pairs(PROXY) do
    Handle[method] = function(self, ...)
        local c = self._c
        if c then
            local f = c[field]
            if f then return f(...) end
        else
            table.insert(self._q, {field, table.pack(...)})
        end
    end
end

function Handle:Get()
    if self._c then return self._c.get() end
end

function Handle:Destroy()
    if self._c and self._c.root then self._c.root:Destroy() end
end

local function finalize(c, o)
    c.setValue = c.setValue or c.set
    c.setSilent = c.setSilent or function(...)
        local cb = o.Callback
        o.Callback = nil
        local ok, err = pcall(c.set, ...)
        o.Callback = cb
        if not ok then warn("[CrunoUI] SetSilent error:", err) end
    end
    c.setInputValue = c.setInputValue or function(v, silent)
        if silent then return c.setSilent(v) end
        return c.set(v)
    end
    if c.root and not c.setVisible then
        c.setVisible = function(v) c.root.Visible = v and true or false end
    end
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
        local h = setmetatable({_q = {}}, Handle)
        defer(self, function()
            local c = B[kind](self, o)
            if not c then return end
            finalize(c, o)
            h._c = c
            if not c.nosave and o.Name ~= nil then Controls[self.Name .. "/" .. tostring(o.Name)] = c end
            for _, item in ipairs(h._q) do
                local f = c[item[1]]
                if f then
                    local ok, err = pcall(f, table.unpack(item[2], 1, item[2].n))
                    if not ok then warn("[CrunoUI]", err) end
                end
            end
            table.clear(h._q)
        end)
        return h
    end
end

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

local function pump()
    if destroyed then return false end
    if not Env then
        local ok, missing = initCore()
        if not ok then return false, missing end
    end
    for _, w in ipairs(Windows) do
        if not w.Built and not w.Building then
            w.Building = true
            local ok, err = pcall(buildWindow, w)
            if not ok then warn("[CrunoUI] 창 생성 실패:", err) end
        end
    end
    return true
end

local injectorStarted = false
local function startInjector()
    if injectorStarted then return end
    injectorStarted = true
    bind(GuiService.MenuOpened, function() task.defer(pump) end)
    task.spawn(function()
        elevate()
        local fails = 0
        while not destroyed do
            local allBuilt = Env ~= nil
            if Env or GuiService.MenuIsOpen then
                local ok, missing = pump()
                if ok == false and not Env then
                    fails += 1
                    if fails == 20 then
                        warn("[CrunoUI] ESC 메뉴 경로를 못 찾음:")
                        for k, v in pairs(missing or {}) do warn(k, v and "OK" or "MISSING") end
                    end
                end
                for _, w in ipairs(Windows) do
                    if not w.Built then allBuilt = false break end
                end
            end
            task.wait(allBuilt and 0.5 or 0.15)
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

local function findWindow(x)
    for _, w in ipairs(Windows) do
        if w == x or w.Name == x or w.Index == x then return w end
    end
    if type(x) == "string" then
        local l = x:lower()
        for _, w in ipairs(Windows) do
            if w.Name:lower() == l then return w end
        end
    end
end

-- ===== ShowTab (v1.2.9) =====
-- 새 스레드 / require / 대기(yield) 없이, Heartbeat 콜백에서 상태머신으로 진행한다.
-- CoreGui를 읽는 곳은 전부 pcall로 보호하고, 읽기가 막히면 GuiService.MenuIsOpen으로 대신 판단한다.
-- 설정창은 가상 ESC로만 연다 (SetMenuIsOpen API는 값만 바꾸고 창을 열지 않으므로 사용하지 않음).
-- 가상 ESC 때문에 게임이 PC로 인식해 모바일 버튼이 사라지는 문제 (v1.2.8 ~ 수정):
--   (1) ESC를 보내는 순간만 LastInputTypeChanged 연결을 잠깐 꺼서
--       게임이 Keyboard 변경을 못 보게 하고, 끝나면 다시 켜고 Touch를 보냄
--   (2) 원래 모바일이면 GetLastInputType()이 계속 Touch를 돌려주도록 후킹
--       (__namecall + hookfunction: 점 호출 방식도 커버, 게임 스크립트 호출에만 적용)
--   (3) LastInputTypeChanged 신호에 Touch를 보내서 컨트롤을 다시 켬

local function getShield()
    return follow(CoreGui, "RobloxGui", "SettingsClippingShield", "SettingsShield")
end

-- 설정창 상태 읽기. 반환: 읽기성공, 화면 안에 있음, shield.Visible
local function readMenu()
    local ok, onScreen, vis = pcall(function()
        local shield = getShield()
        if not shield then return nil end
        local window = follow(shield, "MenuContainer")
        if not window then return nil end
        local ap, as = window.AbsolutePosition, window.AbsoluteSize
        return (as.X > 0 and as.Y > 0 and ap.Y + as.Y > 0), shield.Visible
    end)
    if not ok or onScreen == nil then return false end
    return true, onScreen, vis
end

-- 느슨: 화면 안에 있고 (Visible 이거나 엔진 플래그가 켜져 있음). 못 읽으면 엔진 플래그만 신뢰
local function menuOpenLoose()
    local readable, onScreen, vis = readMenu()
    if readable then return (onScreen and (vis or GuiService.MenuIsOpen)) and true or false end
    return GuiService.MenuIsOpen and true or false
end

-- ESC 키 입력 (CoreGui를 건드리지 않음)
local function pressEscape()
    local vimOk, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if vimOk and vim then
        task.spawn(function()
            pcall(function() vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game) end)
            task.wait(0.05)
            pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game) end)
        end)
        return "vim"
    end
    if keypress and keyrelease then
        task.spawn(function()
            pcall(keypress, 0x1B)
            task.wait(0.05)
            pcall(keyrelease, 0x1B)
        end)
        return "keypress"
    end
    return nil
end

-- 마지막 입력 장치 (속성이 아니라 함수). 라이브러리 내부 호출이라 후킹의 영향을 받지 않음
local function lastInput()
    local ok, t = pcall(function() return UserInputService:GetLastInputType() end)
    if ok then return t end
    return nil
end

-- 원래 모바일(터치)이었는지 판단
local function isTouchDevice()
    if lastInput() == Enum.UserInputType.Touch then return true end
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- GetLastInputType 후킹: spoof.on 일 때 게임 스크립트가 부르면 Touch를 돌려줌.
-- 다시 실행해도 후킹이 겹치지 않도록 env에 한 번만 설치
local spoof = env.CrunoSpoof
if not spoof then
    spoof = {on = false, hooked = false}
    env.CrunoSpoof = spoof
    if hookmetamethod and getnamecallmethod and newcclosure then
        local old
        local ok = pcall(function()
            old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                if spoof.on and self == UserInputService
                    and getnamecallmethod() == "GetLastInputType"
                    and not (checkcaller and checkcaller()) then
                    return Enum.UserInputType.Touch
                end
                return old(self, ...)
            end))
        end)
        spoof.hooked = ok and old ~= nil
    end
end

-- 점 호출 방식(UserInputService.GetLastInputType(UserInputService))도 막기 위한 함수 후킹.
-- 이전 버전이 만든 spoof 테이블이 남아 있어도 한 번만 설치되도록 별도 플래그 사용
if not spoof.fnHooked and hookfunction then
    local wrap = newcclosure or function(f) return f end
    local oldFn
    local ok = pcall(function()
        oldFn = hookfunction(UserInputService.GetLastInputType, wrap(function(self, ...)
            if spoof.on and self == UserInputService
                and not (checkcaller and checkcaller()) then
                return Enum.UserInputType.Touch
            end
            return oldFn(self, ...)
        end))
    end)
    spoof.fnHooked = ok and oldFn ~= nil
end

-- 입력 장치를 터치로 되돌려서 게임의 모바일 버튼이 다시 보이게 함.
-- 게임/컨트롤 모듈은 LastInputTypeChanged 신호로 터치 UI를 켜고 끈다.
local function restoreTouch()
    if destroyed then return end
    local fired = false
    if firesignal then
        fired = pcall(firesignal, UserInputService.LastInputTypeChanged, Enum.UserInputType.Touch)
    end
    if not fired and getconnections then
        pcall(function()
            for _, c in ipairs(getconnections(UserInputService.LastInputTypeChanged)) do
                pcall(function() c:Fire(Enum.UserInputType.Touch) end)
            end
        end)
    end
end

-- 입력 처리가 늦게 반영될 수 있어서 몇 번에 나눠서 시도
local function scheduleRestore(wasTouch)
    if not wasTouch then return end
    for _, t in ipairs({0.1, 0.4, 0.9, 1.6, 3}) do
        task.delay(t, restoreTouch)
    end
end

-- 입력 장치 보호: ESC 키 입력 순간에 게임이 Keyboard 변경을 못 보게 함.
-- LastInputTypeChanged 연결을 잠깐 끄고(Disable), 시간이 지나면 다시 켜고 Touch를 보냄
local guard = {active = false, conns = {}, untilT = 0}

local function guardOn(duration)
    guard.untilT = os.clock() + duration
    if guard.active or not getconnections then return end
    local ok, list = pcall(getconnections, UserInputService.LastInputTypeChanged)
    if not ok or type(list) ~= "table" then return end
    for _, c in ipairs(list) do
        local okE, enabled = pcall(function() return c.Enabled end)
        if okE and enabled ~= false and pcall(function() c:Disable() end) then
            table.insert(guard.conns, c)
        end
    end
    guard.active = #guard.conns > 0
end

local function guardOff()
    if not guard.active and #guard.conns == 0 then return end
    guard.active = false
    local list = guard.conns
    guard.conns = {}
    for _, c in ipairs(list) do pcall(function() c:Enable() end) end
    scheduleRestore(true)
end

-- 설정창을 닫을 때도 입력 장치가 바뀔 수 있으니 한 번 더
bind(GuiService.MenuClosed, function()
    if spoof.on then scheduleRestore(true) end
end)

local showToken = 0
local show = nil
local lastErr, lastErrT = nil, 0

local function endShow(req)
    if show == req then show = nil end
    scheduleRestore(req.wasTouch)
end

local function stepShow(req, now)
    local w = req.w
    local open = menuOpenLoose()

    if req.phase ~= "hold" and now > req.deadline then
        warn("[CrunoUI] ShowTab: 시간 초과 [" .. table.concat(req.log, ", ") .. "] open=" .. tostring(open)
            .. " Env=" .. tostring(Env ~= nil) .. " Built=" .. tostring(w.Built)
            .. " identity=" .. identityStr())
        endShow(req)
        return
    end

    if req.phase == "open" then
        if open then
            req.phase = "reveal"
            req.deadline = now + 6
            return
        end
        if req.attempt >= 5 then return end -- 자동으로 못 열었음: 사용자가 직접 열 때까지 대기

        if req.attempt == 0 then
            if GuiService.MenuIsOpen then
                -- 엔진 플래그는 켜졌는데 UI가 아직 안 보임 (열리는 중일 수 있음) → ESC로 닫아버리지 않게 잠깐 기다림
                req.flagSeen = req.flagSeen or now
                if now - req.flagSeen < 0.4 then return end
            end
            req.attempt = 1
            req.nextAt = now
            return
        end

        if now < req.nextAt then return end

        if req.attempt == 1 or req.attempt == 2 then
            if req.attempt == 2 and GuiService.MenuIsOpen then
                req.attempt = 3 -- 이미 켜져 있는데 ESC를 또 누르면 닫히므로 건너뜀
                return
            end
            if req.wasTouch then guardOn(0.8) end -- ESC 키 입력이 게임에 Keyboard 변경으로 보이지 않게 보호
            local how = pressEscape()
            req.log[#req.log + 1] = "esc" .. req.attempt .. "=" .. tostring(how)
            if how then
                scheduleRestore(req.wasTouch) -- ESC 직후 입력 장치가 키보드로 바뀌는 것을 되돌림
                req.attempt += 1
                req.nextAt = now + 1.2
            else
                req.attempt = 3
            end
        elseif req.attempt == 3 then
            req.log[#req.log + 1] = "flag=" .. tostring(GuiService.MenuIsOpen)
            req.attempt = 5
            req.deadline = req.t0 + 60
            warn("[CrunoUI] ShowTab: 설정창을 자동으로 열지 못함 [" .. table.concat(req.log, ", ")
                .. "] identity=" .. identityStr()
                .. " - ESC로 직접 열면 '" .. w.Name .. "' 탭이 자동으로 선택됩니다.")
        end

    elseif req.phase == "reveal" then
        if not open then return end
        pump()
        local e = Env
        if w.Built and e and e.menuPanel.AbsoluteSize.Y > 0 and e.container.AbsoluteSize.Y > 0 then
            reveal(w)
            req.phase = "hold"
            req.holdUntil = now + 1.2
        end

    elseif req.phase == "hold" then
        -- 열림 애니메이션 / 기본 탭 전환이 끝날 때까지 유지
        if not open then endShow(req) return end
        if active ~= w then
            reveal(w)
        elseif w.page and not w.page.Visible then
            paint(w, true)
        end
        if now >= req.holdUntil then endShow(req) end
    end
end

bind(RunService.Heartbeat, function()
    -- 입력 보호 시간이 끝나면 연결을 다시 켜고 Touch 복구 (show 상태와 무관하게 항상 확인)
    if guard.active and os.clock() >= guard.untilT then guardOff() end

    local req = show
    if not req or destroyed then return end
    pcall(elevate)
    local ok, err = pcall(stepShow, req, os.clock())
    if not ok then
        local msg = tostring(err)
        local t = os.clock()
        if msg ~= lastErr or t - lastErrT > 3 then
            lastErr, lastErrT = msg, t
            warn("[CrunoUI] ShowTab 오류 (phase=" .. tostring(req.phase) .. "):", msg,
                "identity=" .. identityStr())
        end
        req.errCount = (req.errCount or 0) + 1
        if req.errCount > 180 then
            warn("[CrunoUI] ShowTab: 오류가 계속되어 중단함")
            endShow(req)
        end
    end
end)

function Lib.ShowTab(a, b)
    local target = a
    if a == Lib then target = b end
    local w = findWindow(target)
    if not w then
        warn("[CrunoUI] ShowTab: 탭을 찾을 수 없음:", tostring(target))
        return false, "tab not found: " .. tostring(target)
    end
    showToken += 1
    local now = os.clock()
    -- 한 번이라도 모바일로 판단되면 계속 모바일로 취급 (ESC 직후 입력 장치가 Keyboard로 바뀌어도 유지)
    local wasTouch = isTouchDevice() or spoof.touch == true
    if wasTouch then
        spoof.on = true -- 원래 모바일이면 게임에는 계속 터치로 보이게 함
        spoof.touch = true
    end
    show = {
        w = w,
        token = showToken,
        phase = "open",
        attempt = 0,
        nextAt = 0,
        t0 = now,
        deadline = now + 8,
        log = {},
        wasTouch = wasTouch,
    }
    return true
end

function Window:ShowTab(name)
    return Lib.ShowTab(Lib, name ~= nil and name or self)
end

function Window:Show()
    return Lib.ShowTab(Lib, self)
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
    show = nil
    spoof.on = false
    pcall(guardOff) -- 꺼둔 LastInputTypeChanged 연결이 남지 않도록 복구
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