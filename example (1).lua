local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/halingim119-eng/CrunoUI-library/main/CrunoUI.lua"))()

local Win = Lib:AddWindow({Name = "Tab"})

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
    Callback = function() print("버튼 눌림") end,
})

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
    Callback = function(n) print("Amount:", n, typeof(n)) end})

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

Win:AddSection("Select")

Win:AddDropdown({Name = "Target Part", Options = {"Head", "Torso", "HumanoidRootPart"}, Default = "Head",
    Callback = function(v) print("Part:", v) end})

Win:AddMultiDropdown({Name = "ESP Targets", Options = {"Players", "NPCs", "Items", "Chests"},
    Default = {"Players"},
    Callback = function(list) print("Targets:", table.concat(list, ", ")) end})

Win:AddKeybind({Name = "Toggle Key", Default = Enum.KeyCode.RightShift,
    Callback = function(key) print("Key pressed:", key.Name) end})

Win:AddSection("Tools")

Win:AddPath({Name = "Workspace Path", Instance = workspace})
Win:AddPath({Name = "Custom Text", Text = "복사할 아무 문자열"})

Win:AddButton({Name = "Save Config", Label = "Save",
    Callback = function() return (Lib:SaveConfig("default")) end, Success = "Saved!"})
Win:AddButton({Name = "Load Config", Label = "Load",
    Callback = function() return (Lib:LoadConfig("default")) end, Success = "Loaded!"})

local speed = Win:AddSlider({Name = "Handle Demo", Min = 0, Max = 10, Default = 3})

task.spawn(function()
    Lib:WaitReady()
    print("UI ready. ESP =", Lib.Flags.esp)
end)
