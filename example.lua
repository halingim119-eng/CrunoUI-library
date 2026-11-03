-- EscTabLib 사용 예제 (모든 요소)
-- <유저>/<레포> 를 본인 GitHub 주소로 바꾸세요.
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/<유저>/<레포>/main/EscTabLib.lua"))()

-- (선택) 테마 변경: AddWindow 전에 바꿔야 적용됨
-- Lib.Theme.Accent = Color3.fromRGB(255, 80, 120)
-- Lib.Theme.AccentDark = Color3.fromRGB(150, 40, 70)

local Win = Lib:AddWindow({Name = "Tab"})
-- 옵션: ShowProfile = false (프로필/게임 카드 숨김), ShowIP = false (IP/국가 숨김)

----------------------------------------------------------------
Win:AddSection("Main")
Win:AddLabel("ESC 메뉴를 열면 이 탭이 나타납니다")

Win:AddToggle({
    Name = "Show ESP", Default = false, Flag = "esp",
    Callback = function(on) print("ESP:", on) end,
})

Win:AddSelector({
    Name = "WalkSpeed", Options = {16, 32, 50, 100}, Default = 16,
    Callback = function(v)
        local plr = game:GetService("Players").LocalPlayer
        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

Win:AddButton({
    Name = "Test Button", Label = "Run",
    Callback = function() print("버튼 눌림") end,   -- true/false를 return 하면 Done!/Failed 표시
})

----------------------------------------------------------------
Win:AddSection("Values")

Win:AddSlider({Name = "Jump Power", Min = 50, Max = 200, Default = 50, Flag = "jump",
    Callback = function(v) print("Jump:", v) end})
Win:AddSlider({Name = "FOV", Min = 30, Max = 120, Default = 70, Suffix = "°",
    Callback = function(v) workspace.CurrentCamera.FieldOfView = v end})
Win:AddSlider({Name = "Opacity", Min = 0, Max = 1, Default = 0.5, Increment = 0.05,
    Callback = function(v) print("Opacity:", v) end})

Win:AddRange({Name = "Distance", Min = 0, Max = 500, DefaultMin = 50, DefaultMax = 300, Suffix = "m",
    Callback = function(lo, hi) print("Range:", lo, hi) end})

Win:AddInput({Name = "Player Name", Placeholder = "닉네임...",
    Callback = function(text) print("Name:", text) end})
Win:AddInput({Name = "Amount", Default = "100", Numeric = true,
    Callback = function(n) print("Amount:", n, typeof(n)) end})  -- Numeric이면 number로 전달

----------------------------------------------------------------
Win:AddSection("Colors")

Win:AddColorPicker({Name = "ESP Color", Default = Color3.fromRGB(255, 60, 60), Flag = "espColor",
    Callback = function(c) print("Color:", c) end})

Win:AddPalette({
    Name = "Theme Palette",
    Colors = {
        Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 220, 50),
        Color3.fromRGB(80, 210, 90), Color3.fromRGB(0, 190, 200), Color3.fromRGB(0, 146, 214),
        Color3.fromRGB(150, 90, 255), Color3.fromRGB(255, 100, 190),
    },
    Default = 6,
    Callback = function(c) print("Palette:", c) end,
})

----------------------------------------------------------------
Win:AddSection("Select")

Win:AddDropdown({Name = "Target Part", Options = {"Head", "Torso", "HumanoidRootPart"}, Default = "Head",
    Callback = function(v) print("Part:", v) end})

Win:AddMultiDropdown({Name = "ESP Targets", Options = {"Players", "NPCs", "Items", "Chests"},
    Default = {"Players"},
    Callback = function(list) print("Targets:", table.concat(list, ", ")) end})

Win:AddKeybind({Name = "Toggle Key", Default = Enum.KeyCode.RightShift,
    Callback = function(key) print("Key pressed:", key.Name) end})

----------------------------------------------------------------
Win:AddSection("Tools")

Win:AddPath({Name = "Workspace Path", Instance = workspace})            -- 눌러서 경로 복사
Win:AddPath({Name = "Custom Text", Text = "복사할 아무 문자열"})

Win:AddButton({Name = "Save Config", Label = "Save",
    Callback = function() return (Lib:SaveConfig("default")) end, Success = "Saved!"})
Win:AddButton({Name = "Load Config", Label = "Load",
    Callback = function() return (Lib:LoadConfig("default")) end, Success = "Loaded!"})

----------------------------------------------------------------
-- 핸들 사용: 코드에서 값을 읽고/바꾸기
local speed = Win:AddSlider({Name = "Handle Demo", Min = 0, Max = 10, Default = 3})
-- speed:Set(7)       -- 값 변경 (콜백도 실행됨)
-- print(speed:Get()) -- 현재 값 (탭이 만들어진 뒤에만 값이 있음)

-- Flags: Lib.Flags.esp, Lib.Flags.jump, Lib.Flags.espColor ...
task.spawn(function()
    Lib:WaitReady()  -- ESC 메뉴를 처음 열어 탭이 생성될 때까지 대기
    print("UI ready. ESP =", Lib.Flags.esp)
end)
