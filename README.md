# EscTabLib

UI, 모바일지원, Config 저장/불러오기, 테마 변경.

- 토글 / 선택기 / 버튼 / 슬라이더 / 범위 슬라이더 / 입력창
- 컬러픽커 / 팔레트 / 드롭다운 / 멀티 드롭다운 / 키바인드
- 섹션 / 라벨 / 경로 복사 카드
- 여러 개의 탭(창) 추가 가능

---

## 1. 설치

1. 이 레포에 `EscTabLib.lua`를 올립니다.
2. 실행기에서 아래처럼 불러옵니다. (

```lua
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/<유저>/<레포>/main/EscTabLib.lua"))()
```



---

## 2. 빠른 시작

```lua
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/<유저>/<레포>/main/EscTabLib.lua"))()

local Win = Lib:AddWindow({Name = "Tab"})

Win:AddSection("Main")
Win:AddToggle({
    Name = "Show ESP",
    Default = false,
    Flag = "esp",
    Callback = function(on) print("ESP:", on) end,
})
Win:AddSlider({Name = "FOV", Min = 30, Max = 120, Default = 70, Suffix = "°",
    Callback = function(v) workspace.CurrentCamera.FieldOfView = v end})
```

**ESC 키(또는 메뉴 버튼)를 눌러 메뉴를 열면** 탭이 나타납니다. 전체 예제는 `example.lua` 참고.



- 값이 필요할 땐 `Callback`을 쓰는 게 가장 안전합니다.
- 생성 이후에 뭔가 해야 하면 `Lib:WaitReady()`로 기다리세요.

---

## 3. 라이브러리 API (`Lib`)

| 이름 | 설명 |
|---|---|
| `Lib:AddWindow(opts)` | 탭(창) 하나 추가. `Window` 반환 |
| `Lib:SaveConfig(name?)` | 모든 컨트롤 값을 파일로 저장. `ok, 파일명` 반환 |
| `Lib:LoadConfig(name?)` | 저장한 값을 불러와 적용. `ok, 파일명/사유` 반환 |
| `Lib:WaitReady()` | 모든 창이 만들어질 때까지 대기 (yield) |
| `Lib:Destroy()` | 탭 제거 + 연결 해제 + 원래대로 복원 |
| `Lib.Flags` | `Flag` 이름 → 현재 값 테이블 |
| `Lib.Theme` | 색상 테마 (AddWindow 전에 수정) |
| `Lib.ConfigFolder` | Config 폴더 이름 (기본 `"EscTabConfigs"`) |
| `Lib.PickerYOffset` | 컬러픽커 세로 드래그가 손가락과 어긋날 때 보정(px). 양수 = 아래로 |
| `Lib.SidePad` | 페이지 좌우 여백 (기본 10) |
| `Lib.ResumeTexts` | 하단 "계속하기" 바를 찾는 글자 목록. 클라이언트 언어가 달라 페이지가 하단 바를 가리면 여기에 해당 글자를 추가 |
| `Lib.Version` | 버전 문자열 |

> 같은 스크립트를 다시 실행하면 이전 인스턴스는 자동으로 `Destroy`되고 새로 만들어집니다.

### `Lib:AddWindow(opts)`

```lua
local Win = Lib:AddWindow({
    Name = "Tab",          -- 탭에 표시될 글자 (Config 키에도 쓰임)
    ShowProfile = true,    -- 맨 위 프로필/게임 카드 (false로 끄기)
    ShowIP = true,         -- 프로필의 IP/국가 표시 (false면 Hidden, 네트워크 요청도 안 함)
})
```
문자열만 넘겨도 됩니다: `Lib:AddWindow("Tab")`.
창을 여러 개 만들면 탭이 여러 개 생기고, 탭 너비는 자동으로 나눠집니다.

### `Window` 메서드

| 메서드 | 설명 |
|---|---|
| `Win:Show()` | 이 탭을 열린 상태로 (메뉴가 열려 있고 만들어진 뒤) |
| `Win:Close()` | 이 탭 닫기 |
| `Win:AddXxx(...)` | 아래 4번의 요소들 |

---

## 4. 요소(컨트롤) 사용법

모든 요소는 **옵션 테이블**을 받고, **핸들(Handle)** 을 반환합니다.
문자열만 받는 건 `AddSection`, `AddLabel`뿐입니다.

### 공통 옵션

| 옵션 | 설명 |
|---|---|
| `Name` | 왼쪽에 표시되는 이름. **Config 키**이므로 한 창 안에서 겹치지 않게 |
| `Callback` | 값이 바뀔 때 호출되는 함수 |
| `Flag` | 지정하면 `Lib.Flags[Flag]`에 현재 값이 자동 저장 |
| `Silent` | `true`면 생성 직후의 첫 `Callback` 호출을 생략 (기본은 기본값으로 한 번 호출됨) |

### 핸들 (반환값)

```lua
local t = Win:AddToggle({Name = "ESP", Default = false})
t:Set(true)      -- 값 변경 (UI도 바뀌고 Callback도 실행됨)
print(t:Get())   -- 현재 값 (탭이 만들어지기 전엔 nil)
```
탭이 만들어지기 전에 `:Set()`을 부르면 만들어질 때 자동 적용됩니다.

---

### AddSection / AddLabel
```lua
Win:AddSection("제목")          -- 큰 글씨 제목
Win:AddLabel("설명 글자")       -- 회색 안내 문구 카드
local lb = Win:AddLabel("Status: idle")
lb:Set("Status: running")       -- 글자 변경
```

### AddToggle — 스위치
| 옵션 | 타입 | 기본 | 설명 |
|---|---|---|---|
| `Default` | boolean | false | 시작 상태 |
| `Callback(on)` | function | | boolean 전달 |

```lua
Win:AddToggle({Name = "Auto Farm", Default = false, Callback = function(on) end})
```

### AddSelector — ‹ 값 › 순환 선택
| 옵션 | 설명 |
|---|---|
| `Options` | 값 목록 (숫자/문자열) |
| `Default` | 기본 **값** (없으면 인덱스로 해석, 그것도 없으면 1번) |
| `Callback(value)` | 선택된 값 |

```lua
Win:AddSelector({Name = "WalkSpeed", Options = {16, 32, 50, 100}, Default = 16,
    Callback = function(v) end})
```

### AddButton — 누르면 실행
| 옵션 | 설명 |
|---|---|
| `Callback()` | 눌렀을 때 실행. `true`를 return하면 성공 표시, `false`면 실패 표시, 아무것도 안 return하면 표시 없음 |
| `Label` | 오른쪽 글자 (기본 `"Run"`) |
| `Success` | 성공 시 글자 (기본 `"Done!"`) |
| `Failure` | 실패 시 글자 (기본 `"Failed"`) |

```lua
Win:AddButton({Name = "Copy Info", Label = "Copy", Success = "Copied!",
    Callback = function() return setclipboard ~= nil end})
```
버튼은 Config에 저장되지 않습니다.

### AddSlider — 값 슬라이더
| 옵션 | 기본 | 설명 |
|---|---|---|
| `Min`, `Max` | 0, 100 | 범위 |
| `Default` | Min | 시작 값 |
| `Increment` | 1 | 단위 (`0.05`처럼 소수 가능) |
| `Suffix` | `""` | 값 뒤에 붙는 글자 (`"%"`, `"°"`, `"m"`) |
| `Callback(value)` | | number |

```lua
Win:AddSlider({Name = "Volume", Min = 0, Max = 100, Default = 50, Suffix = "%",
    Callback = function(v) end})
```

### AddRange — 최소~최대 두 값
| 옵션 | 설명 |
|---|---|
| `Min`, `Max` | 전체 범위 |
| `DefaultMin`, `DefaultMax` | 시작 범위 |
| `Suffix` | 글자 |
| `Callback(lo, hi)` | 두 값 |

```lua
local r = Win:AddRange({Name = "Distance", Min = 0, Max = 500, DefaultMin = 50, DefaultMax = 300,
    Suffix = "m", Callback = function(lo, hi) end})
r:Set(100, 400)       -- 또는 r:Set({100, 400})
local range = r:Get() -- {lo, hi}
```
`Flag`는 `{lo, hi}` 테이블로 저장됩니다. 바를 누른 위치에서 가까운 쪽 손잡이가 움직입니다.

### AddInput — 입력창
| 옵션 | 설명 |
|---|---|
| `Default` | 시작 글자 |
| `Placeholder` | 안내 글자 |
| `Numeric` | `true`면 숫자/`.`/`-`만 허용, **Callback에 number 전달** |
| `Callback(text)` | 입력을 끝냈을 때(포커스 해제) 호출 |

```lua
Win:AddInput({Name = "Player Name", Callback = function(text) end})
Win:AddInput({Name = "Amount", Default = "100", Numeric = true, Callback = function(n) end})
```

### AddColorPicker — SV 사각형 + Hue 바 + 헥스 입력
| 옵션 | 설명 |
|---|---|
| `Default` | `Color3` |
| `Callback(color)` | `Color3` |

```lua
local c = Win:AddColorPicker({Name = "ESP Color", Default = Color3.fromRGB(255, 60, 60),
    Callback = function(color) end})
c:Set("#00FF88")             -- 헥스 문자열 또는 Color3
print(c:Get())               -- "#00FF88" (헥스 문자열)
```
오른쪽 색 칸을 누르면 펼쳐집니다. 헥스 칸에 `#RRGGBB`를 직접 입력해도 됩니다.
세로 드래그가 손가락 위치와 어긋나면 `Lib.PickerYOffset`을 조절하세요.

### AddPalette — 프리셋 색 격자
| 옵션 | 설명 |
|---|---|
| `Colors` | `Color3` 배열 (한 줄에 8개씩 배치) |
| `Default` | 기본 선택 (인덱스 또는 `Color3`) |
| `Callback(color)` | 선택한 `Color3` |

```lua
Win:AddPalette({Name = "Theme", Colors = {
    Color3.fromRGB(255, 60, 60), Color3.fromRGB(80, 210, 90), Color3.fromRGB(0, 146, 214),
}, Default = 3, Callback = function(c) end})
```

### AddDropdown — 하나 선택
| 옵션 | 설명 |
|---|---|
| `Options` | 문자열 배열 |
| `Default` | 기본 값 (없으면 첫 항목) |
| `Callback(value)` | 선택된 값 |

```lua
Win:AddDropdown({Name = "Target Part", Options = {"Head", "Torso", "HumanoidRootPart"},
    Default = "Head", Callback = function(v) end})
```

### AddMultiDropdown — 여러 개 체크
| 옵션 | 설명 |
|---|---|
| `Options` | 문자열 배열 |
| `Default` | 기본으로 체크할 항목 배열 |
| `Callback(list)` | 선택된 항목 배열 (Options 순서) |

```lua
local m = Win:AddMultiDropdown({Name = "ESP Targets", Options = {"Players", "NPCs", "Items"},
    Default = {"Players"}, Callback = function(list) print(table.concat(list, ", ")) end})
m:Set({"NPCs", "Items"})
```

### AddKeybind — 키 지정
| 옵션 | 설명 |
|---|---|
| `Default` | `Enum.KeyCode` (또는 `"RightShift"` 같은 이름 문자열). 없으면 미지정 |
| `Callback(keyCode)` | **지정한 키를 눌렀을 때** 호출 (키 지정 자체로는 호출되지 않음) |

```lua
Win:AddKeybind({Name = "Toggle Key", Default = Enum.KeyCode.RightShift,
    Callback = function(key) print(key.Name) end})
```
칸을 누르고 원하는 키를 누르면 지정됩니다. **Esc = 취소, Backspace = 키 해제**. `Lib.Flags`에는 `Enum.KeyCode` 값이 들어갑니다.

### AddPath — 눌러서 복사
| 옵션 | 설명 |
|---|---|
| `Instance` | 인스턴스를 주면 `GetFullName()` 경로를 표시/복사 |
| `Text` | 직접 문자열을 줄 수도 있음 (`Instance`보다 우선) |

```lua
Win:AddPath({Name = "Workspace", Instance = workspace})
Win:AddPath({Name = "Discord", Text = "discord.gg/xxxx"})
```
`setclipboard`가 없으면 "Clipboard not supported"가 표시됩니다.

---

## 5. Flags — 값을 어디서든 읽기

`Flag = "이름"`을 주면 값이 바뀔 때마다 `Lib.Flags["이름"]`이 갱신됩니다.

```lua
Win:AddToggle({Name = "Auto Farm", Flag = "farm"})
Win:AddSlider({Name = "Delay", Min = 1, Max = 10, Default = 3, Flag = "delay"})

task.spawn(function()
    while task.wait() do
        if Lib.Flags.farm then
            -- 파밍 로직
            task.wait(Lib.Flags.delay)
        end
    end
end)
```
Flags는 해당 요소가 만들어진 뒤(메뉴를 처음 연 뒤)부터 값이 있습니다. 루프에서는 `Lib.Flags.farm`이 `nil`이어도 안전하게 동작하도록 쓰세요(위 예시처럼).

---

## 6. Config 저장 / 불러오기

```lua
Lib:SaveConfig()            -- config_20260101_120000.json 처럼 시간 이름으로 저장
Lib:SaveConfig("legit")     -- legit.json 으로 저장 (덮어쓰기)

Lib:LoadConfig()            -- 가장 최근의 자동 이름(config_...) 파일 불러오기
Lib:LoadConfig("legit")     -- legit.json 불러오기
```
- 저장 위치: 실행기 workspace의 `EscTabConfigs/` 폴더
- 키는 `"창이름/요소이름"` 입니다. **이름을 바꾸면 이전 값이 적용되지 않아요.**
- 저장되는 요소: Toggle, Selector, Slider, Range, Input, ColorPicker, Palette, Dropdown, MultiDropdown, Keybind
- 저장 안 되는 요소: Section, Label, Button, Path
- 불러오면 각 요소의 `Callback`이 실행되어 실제 기능에도 바로 반영됩니다.
- 반환값은 `성공여부, 파일명(또는 실패 사유)` 입니다.

버튼으로 만들고 싶다면:
```lua
Win:AddButton({Name = "Save", Label = "Save", Success = "Saved!",
    Callback = function() return (Lib:SaveConfig("default")) end})
Win:AddButton({Name = "Load", Label = "Load", Success = "Loaded!",
    Callback = function() return (Lib:LoadConfig("default")) end})
```

---

## 7. 테마

`AddWindow` **전에** 바꾸세요.

```lua
Lib.Theme.Accent = Color3.fromRGB(255, 80, 120)      -- 포인트 색 (켜진 토글, 포커스 테두리)
Lib.Theme.AccentDark = Color3.fromRGB(150, 40, 70)   -- 슬라이더 채움, 선택된 항목
```

| 키 | 용도 |
|---|---|
| `Text` | 기본 글자 |
| `Row` / `Hover` | 카드 배경 / 마우스 올린 배경 |
| `Field` | 입력칸·드롭다운 머리 배경 |
| `Stroke` | 테두리 |
| `Muted` | 보조 글자 |
| `Off` | 꺼진 토글 / 체크 해제 |
| `Accent` / `AccentDark` | 포인트 색 |
| `Bar` | 슬라이더 바 배경 |
| `Danger` | 실패 표시 |
| `Avatar` | 프로필/게임 썸네일 배경 |

---

## 8. 자주 묻는 문제

**탭이 안 보여요**
ESC 메뉴를 한 번 열어 보세요. 5초 이상 계속 안 되면 콘솔에 `경로를 못 찾음` 경고가 뜹니다. Roblox가 메뉴 구조를 바꾼 경우이며, `getRefs()` 안의 경로를 수정해야 합니다.

**텍스트에 테두리가 생겨요**
v1.0.0은 모든 `UIStroke`를 `Border` 모드로 고정해서 이 문제가 없습니다. 직접 `UIStroke`를 추가한다면 `ApplyStrokeMode = Enum.ApplyStrokeMode.Border`를 지정하세요.

**페이지 아래쪽이 "계속하기" 바에 가려져요**
클라이언트 언어에 따라 바 글자가 다릅니다. `Lib.ResumeTexts`에 해당 글자를 추가하세요.
```lua
table.insert(Lib.ResumeTexts, "여기에 실제 버튼 글자")
```

**컬러픽커 드래그 위치가 어긋나요**
`Lib.PickerYOffset = 20` 처럼 값을 넣어 보정하세요. 양수면 아래로 이동합니다.

**IP를 화면에 보이고 싶지 않아요**
`Lib:AddWindow({Name = "Tab", ShowIP = false})` 또는 `ShowProfile = false`.

**스크립트를 다시 실행하면?**
이전 탭이 자동으로 지워지고 새로 만들어집니다.

---

## 파일 구성

| 파일 | 설명 |
|---|---|
| `EscTabLib.lua` | 라이브러리 본체 (`loadstring` 대상) |
| `example.lua` | 모든 요소 사용 예제 |
| `README.md` | 이 문서 |
