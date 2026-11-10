local lbl = win:AddLabel({
    Text = "서버에 접속 중입니다. 잠시만 기다려 주세요.",
    Icon = "info",
    IconColor = Color3.fromRGB(0, 146, 214),
    Color = Color3.new(1, 1, 1),
    TextSize = 14,
    Lines = 2,
    Align = "Left",
})

lbl:SetText("접속 완료!")
lbl:SetColor(Color3.fromRGB(80, 200, 120))
lbl:SetIcon("check")
lbl:SetLines(1)