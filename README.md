# CrunoUI

로블록스 ESC 메뉴에 탭을 하나 더 추가해서 스크립트용 메뉴를 만들 수 있는 라이브러리입니다. 모바일 터치도 됩니다.

## 불러오기

```lua
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/halingim119-eng/CrunoUI-library/main/CrunoUI.lua"))()
```

## 기본 사용

```lua
local Win = Lib:AddWindow({Name = "Tab"})

Win:AddSection("Main")

Win:AddToggle({
    Name = "ESP",
    Default = false,
    Callback = function(on)
        print(on)
    end,
})

Win:AddSlider({Name = "FOV", Min = 30, Max = 120, Default = 70, Suffix = "°"})
```

ESC 메뉴를 열면 탭이 나타납니다. 탭은 메뉴를 처음 열 때 만들어지고, 그 전에 적은 코드는 자동으로 기다렸다가 적용됩니다. 모든 요소 예제는 `example.lua`에 있습니다.

## 창 만들기

```lua
Lib:AddWindow({
    Name = "Tab",
    ShowProfile = true,
    ShowIP = true,
})
```

- Name: 탭에 보이는 글자
- ShowProfile: false로 하면 맨 위 프로필, 게임 정보 카드가 사라집니다
- ShowIP: false로 하면 IP와 국가를 숨깁니다

창을 여러 번 만들면 탭이 여러 개 생깁니다.

## 요소

모든 요소는 `Win:AddXxx({옵션})` 형태입니다. 아래 옵션은 모든 요소에 공통입니다.

- Name: 왼쪽에 보이는 이름. 같은 창 안에서 겹치면 안 됩니다
- Callback: 값이 바뀔 때 실행할 함수. 만들어진 직후에도 기본값으로 한 번 실행됩니다 (막으려면 Silent = true)
- Flag: 이름을 적으면 `Lib.Flags.이름`으로 현재 값을 어디서든 읽을 수 있습니다

### Toggle
켜고 끄는 스위치. Default(true/false). 함수에 true/false가 들어옵니다.

### Selector
좌우 화살표로 값을 넘기는 선택기. Options(목록), Default(처음 값).

### Button
누르면 Callback 실행. Label은 오른쪽 글자. 함수가 true를 돌려주면 Success 글자, false를 돌려주면 Failure 글자가 잠깐 보입니다.

### Slider
Min, Max, Default, Increment(단위, 소수 가능), Suffix(값 뒤에 붙는 글자).

### Range
최솟값과 최댓값을 함께 고르는 슬라이더. Min, Max, DefaultMin, DefaultMax, Suffix. 함수에 (작은 값, 큰 값)이 들어옵니다.

### Input
글자 입력칸. Default, Placeholder. Numeric = true면 숫자만 입력되고 숫자로 전달됩니다. 입력을 마쳤을 때 실행됩니다.

### ColorPicker
색 선택. Default(Color3). 오른쪽 색 칸을 누르면 펼쳐지고, #RRGGBB를 직접 입력해도 됩니다.

### Palette
미리 정한 색 중에서 고르기. Colors(Color3 목록), Default(번호 또는 색).

### Dropdown
하나만 고르는 목록. Options, Default.

### MultiDropdown
여러 개 체크하는 목록. Options, Default(처음 체크할 항목들). 함수에 선택된 항목 목록이 들어옵니다.

### Keybind
키 지정. Default(`Enum.KeyCode.RightShift` 등). 칸을 누르고 키를 누르면 바뀌고, Esc는 취소, Backspace는 지정 해제입니다. 지정한 키를 누를 때 Callback이 실행됩니다.

### Section, Label
```lua
Win:AddSection("제목")
Win:AddLabel("설명 글자")
```

### Path
누르면 복사되는 카드. Instance를 주면 그 경로가, Text를 주면 그 글자가 복사됩니다.

## 값 읽고 바꾸기

요소를 만들 때 돌려받은 값으로 직접 읽거나 바꿀 수 있습니다.

```lua
local t = Win:AddToggle({Name = "Auto", Default = false})
t:Set(true)
print(t:Get())
```

Range의 Get은 `{작은 값, 큰 값}` 표를 돌려줍니다. ColorPicker의 Get은 `"#RRGGBB"` 글자입니다.

## 설정 저장

```lua
Lib:SaveConfig("내설정")
Lib:LoadConfig("내설정")
```

이름을 생략하면 저장은 날짜 이름으로, 불러오기는 가장 최근 날짜 이름 파일로 처리됩니다. 파일은 실행기 workspace의 `CrunoUI` 폴더에 생기고, 요소의 Name이 바뀌면 이전 값은 적용되지 않습니다. Button, Label, Section, Path는 저장되지 않습니다.

## 기타

- `Lib:WaitReady()`: 탭이 전부 만들어질 때까지 기다립니다
- `Lib:Destroy()`: 탭을 지우고 원래대로 되돌립니다. 스크립트를 다시 실행하면 자동으로 먼저 실행됩니다
- `Lib.Theme.Accent = Color3.fromRGB(...)`: 포인트 색 변경. `Lib:AddWindow` 전에 바꿔야 합니다. Theme 안에 Text, Row, Hover, Field, Stroke, Muted, Off, AccentDark, Bar, Danger, Avatar도 있습니다
- `Lib.PickerYOffset`: 컬러픽커를 세로로 드래그할 때 손가락과 위치가 어긋나면 이 숫자(양수면 아래로)를 조절합니다
- `Lib.ResumeTexts`: 페이지 아래쪽이 메뉴 하단 버튼에 가려지면, 그 버튼에 적힌 글자를 `table.insert(Lib.ResumeTexts, "글자")`로 추가합니다

## 문제가 생기면

- 탭이 안 보임: ESC 메뉴를 한 번 열어보세요. 계속 안 보이면 콘솔에 경고가 뜹니다. 로블록스 메뉴 구조가 바뀐 경우입니다
- 복사가 안 됨, 설정 저장이 안 됨: 사용하는 실행기가 클립보드, 파일 저장을 지원하지 않는 경우입니다
