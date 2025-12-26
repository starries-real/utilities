--> ImGui Builder dengan Error Handler

Gui = Gui or {}

-- \ ImGui State Tracker untuk Error Recovery
local GuiState = {
    ChildDepth = 0,
    WindowDepth = 0,
    GroupDepth = 0,
    DisabledDepth = 0,
    ColorPushCount = 0,
    StylePushCount = 0,
    FontPushCount = 0,
    IdPushCount = 0,
    ItemWidthPushCount = 0,
    LastError = nil,
    ErrorCount = 0
}

-- \ Safe Call dengan Error Reporting
function SafeCall(Fn, Location, ...)
    if type(Fn) ~= "function" then return end
    
    local Ok, Err = pcall(Fn, ...)
    if not Ok then
        local ErrorMsg = SafeToString(Err)
        GuiState.LastError = Location .. ": " .. ErrorMsg
        GuiState.ErrorCount = GuiState.ErrorCount + 1
        
        if Console then 
            Console("[`6Gui Error`o] " .. Location .. " => " .. ErrorMsg, "Error") 
        end
        
        -- Report ke webhook jika error handler tersedia
        if ReportError then
            ReportError("Gui." .. Location, ErrorMsg, debug.traceback(Err, 2))
        end
        
        -- Log ke file
        if Log then
            Log("Gui Error at " .. Location .. ": " .. ErrorMsg, "Error")
        end
    end
end

-- \ Dimension Validation
function ValidateDimension(Value, Max, Min)
    Min = Min or 0
    Max = Max or 9999
    
    if type(Value) ~= "number" then return Min end
    if Value ~= Value then return Min end -- NaN check
    if Value == math.huge or Value == -math.huge then return Max end
    if Value < Min then return Min end
    if Value > Max then return Max end
    
    return Value
end

function ValidateChildSize(Width, Height)
    local WorldX, WorldY = 100, 60
    if GetWorldSize then
        WorldX, WorldY = GetWorldSize()
    end
    
    -- Safety margin dari world size
    local MaxWidth = math.max(100, (WorldX or 100) - 20)
    local MaxHeight = math.max(50, (WorldY or 60) - 20)
    
    Width = ValidateDimension(Width, MaxWidth, 10)
    Height = ValidateDimension(Height, MaxHeight, 10)
    
    return Width, Height
end

-- \ Stack Cleanup Function
function CleanupGuiStack()
    SafeCall(function()
        -- Pop colors
        if GuiState.ColorPushCount > 0 and ImGui.PopStyleColor then
            for _ = 1, GuiState.ColorPushCount do
                ImGui.PopStyleColor()
            end
        end
        
        -- Pop styles
        if GuiState.StylePushCount > 0 and ImGui.PopStyleVar then
            for _ = 1, GuiState.StylePushCount do
                ImGui.PopStyleVar()
            end
        end
        
        -- Pop fonts
        if GuiState.FontPushCount > 0 and ImGui.PopFont then
            for _ = 1, GuiState.FontPushCount do
                ImGui.PopFont()
            end
        end
        
        -- Pop item width
        if GuiState.ItemWidthPushCount > 0 and ImGui.PopItemWidth then
            for _ = 1, GuiState.ItemWidthPushCount do
                ImGui.PopItemWidth()
            end
        end
        
        -- Pop IDs
        if GuiState.IdPushCount > 0 and ImGui.PopID then
            for _ = 1, GuiState.IdPushCount do
                ImGui.PopID()
            end
        end
        
        -- Close children
        if GuiState.ChildDepth > 0 and ImGui.EndChild then
            for _ = 1, GuiState.ChildDepth do
                ImGui.EndChild()
            end
        end
        
        -- Close windows
        if GuiState.WindowDepth > 0 and ImGui.End then
            for _ = 1, GuiState.WindowDepth do
                ImGui.End()
            end
        end
        
        -- Close groups
        if GuiState.GroupDepth > 0 and ImGui.EndGroup then
            for _ = 1, GuiState.GroupDepth do
                ImGui.EndGroup()
            end
        end
        
        -- Close disabled
        if GuiState.DisabledDepth > 0 and ImGui.EndDisabled then
            for _ = 1, GuiState.DisabledDepth do
                ImGui.EndDisabled()
            end
        end
    end, "CleanupGuiStack")
    
    GuiState.ColorPushCount = 0
    GuiState.StylePushCount = 0
    GuiState.FontPushCount = 0
    GuiState.ItemWidthPushCount = 0
    GuiState.IdPushCount = 0
    GuiState.ChildDepth = 0
    GuiState.WindowDepth = 0
    GuiState.GroupDepth = 0
    GuiState.DisabledDepth = 0
end

-- \ Basic

function Gui.Paragraph(Text, Width, Indent)
    Indent = Indent or 6
    SafeCall(function()
        Gui.Indent(Indent)
        ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + (Width or 260))
        Gui.TextWrapped(tostring(Text or ""))
        ImGui.PopTextWrapPos()
        Gui.Unindent(Indent)
    end, "Paragraph")
end

function Gui.RadioGroupKey(Options, StateTable, Key, IdSuffix)
    SafeCall(function()
        IdSuffix = tostring(IdSuffix or "")
        for i, Name in ipairs(Options or {}) do
            local Label = tostring(Name)
            if IdSuffix ~= "" then
                Label = Label .. "##" .. IdSuffix .. "_" .. tostring(i)
            end
    
            if ImGui.RadioButton(Label, StateTable[Key] == Name) then
                StateTable[Key] = Name
            end
            if i < #Options then Gui.SameLine() end
        end
    end, "RadioGroupKey")
end

function Gui.InputTextKey(Label, StateTable, Key, MaxLen, Width, Flags)
    SafeCall(function()
        if type(StateTable) ~= "table" or not Key then return false, "" end
        StateTable[Key] = tostring(StateTable[Key] or "")
        local Buffer = StateTable[Key]
        if Width then ImGui.PushItemWidth(Width); GuiState.ItemWidthPushCount = GuiState.ItemWidthPushCount + 1 end
        local Changed, NewText = ImGui.InputText(Label, Buffer, MaxLen or 256, Flags or 0)
        if Width then ImGui.PopItemWidth(); GuiState.ItemWidthPushCount = math.max(0, GuiState.ItemWidthPushCount - 1) end
        if Changed then StateTable[Key] = NewText end
        return Changed, StateTable[Key]
    end, "InputTextKey")
end

function Gui.RowButtons(Buttons, DefaultSize)
    SafeCall(function()
        for Index, Btn in ipairs(Buttons or {}) do
            if Index > 1 then Gui.SameLine() end
            local Size = Btn.Size or DefaultSize or ImVec2(0, 23)
            Gui.Button(tostring(Btn.Label or "Button"), Size, Btn.OnClick, Btn.Tooltip)
        end
    end, "RowButtons")
end

function Gui.ToggleCheatNames(Names, ConfigMapping)
    SafeCall(function()
        for _, OptionName in ipairs(Names or {}) do
            if Cheats and Cheats[OptionName] ~= nil then
                local NewValue = not Cheats[OptionName]
                Cheats[OptionName] = NewValue
                local ConfigKey = ConfigMapping and ConfigMapping[OptionName]
                if ConfigKey and ChangeValue then ChangeValue(ConfigKey, NewValue) end
            end
        end
    end, "ToggleCheatNames")
end

function Gui.CheatToggleMapped(OptionName, ConfigKey, TooltipText)
    local CurrentValue = false
    
    SafeCall(function()
        if type(OptionName) ~= "string" then return false, false end
        
        if ConfigKey and GetValue then
            if OptionName == "Anti Lag" then
                local Particle = (GetValue("[C] No render particle") or false) == true
                local Shadow = (GetValue("[C] No render shadow") or false) == true
                local Name = (GetValue("[C] No render name") or false) == true
                CurrentValue = (Particle and Shadow and Name)
            else
                CurrentValue = (GetValue(ConfigKey) or false) == true
            end
        else
            CurrentValue = (Cheats and Cheats[OptionName] == true) or false
        end
    end, "CheatToggleMapped.GetValue")
    
    SafeCall(function()
        local Changed, NewValue = ImGui.Checkbox(OptionName, CurrentValue)
        
        if TooltipText and TooltipText ~= "" then
            Gui.Tooltip(TooltipText)
        end
        
        if not Changed then return false, CurrentValue end
        
        if ConfigKey and ChangeValue then
            if OptionName == "Anti Lag" then
                ChangeValue("[C] No render particle", NewValue)
                ChangeValue("[C] No render shadow", NewValue)
                ChangeValue("[C] No render name", NewValue)
            else
                ChangeValue(ConfigKey, NewValue)
            end
        end
        
        if Cheats then Cheats[OptionName] = NewValue end
        
        return true, NewValue
    end, "CheatToggleMapped.SetValue")
    
    return false, CurrentValue
end

function Gui.SetCheatListMapped(OptionList, Enable, ConfigMapping)
    SafeCall(function()
        if not Cheats or type(OptionList) ~= "table" then return end
        for _, OptionName in ipairs(OptionList) do
            if type(OptionName) == "string" then
                Cheats[OptionName] = Enable
                local ConfigKey = ConfigMapping and ConfigMapping[OptionName]
                if ConfigKey and ChangeValue then
                    if OptionName == "Anti Lag" then
                        ChangeValue("[C] No render particle", Enable)
                        ChangeValue("[C] No render shadow", Enable)
                        ChangeValue("[C] No render name", Enable)
                    else
                        ChangeValue(ConfigKey, Enable)
                    end
                end
            end
        end
    end, "SetCheatListMapped")
end

function Gui.CleanLabel(Label)
    local Result = SafeToString(Label or "")
        :gsub("^[^\x20-\x7E]+", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    return Result
end

function Gui.BuildTabs(Labels, IdPrefix, ResolveFn, FallbackFn)
    local Tabs = {}
    SafeCall(function()
        for _, RawLabel in ipairs(Labels or {}) do
            local CleanName = Gui.CleanLabel(RawLabel)
            Tabs[#Tabs + 1] = {
                Label = RawLabel,
                Draw = function()
                    Gui.Child("##" .. tostring(IdPrefix or "Tabs") .. "_" .. CleanName, 0, true, function()
                        local Fn = ResolveFn and ResolveFn(CleanName, RawLabel) or nil
                        if type(Fn) == "function" then
                            Fn()
                        elseif type(FallbackFn) == "function" then
                            FallbackFn()
                        else
                            if DrawBlank then DrawBlank(0.50, 2) end
                        end
                    end)
                end
            }
        end
    end, "BuildTabs")
    return Tabs
end

function Gui.Header(Text)
    SafeCall(function()
        ImGui.Text(tostring(Text or ""))
        Gui.Spacing(1)
        ImGui.Separator()
        Gui.Spacing(1)
    end, "Header")
end

function Gui.SubHeader(Text)
    SafeCall(function()
        Gui.TextDisabled(tostring(Text or ""))
        Gui.Separator()
    end, "SubHeader")
end

function Gui.Spacing(Count)
    SafeCall(function()
        local N = tonumber(Count) or 1
        for _ = 1, N do ImGui.Spacing() end
    end, "Spacing")
end

function Gui.Separator()
    SafeCall(function()
        if DrawSeparator then
            DrawSeparator()
        else
            Gui.Spacing(1)
            ImGui.Separator()
            Gui.Spacing(1)
        end
    end, "Separator")
end

function Gui.SameLine(OffsetX, Spacing)
    SafeCall(function()
        if OffsetX ~= nil or Spacing ~= nil then
            ImGui.SameLine(OffsetX or 0, Spacing or -1)
        else
            ImGui.SameLine()
        end
    end, "SameLine")
end

function Gui.AlignText()
    SafeCall(function()
        ImGui.AlignTextToFramePadding()
    end, "AlignText")
end

function Gui.Dummy(W, H)
    SafeCall(function()
        ImGui.Dummy(ImVec2(ValidateDimension(W, 9999, 0), ValidateDimension(H, 9999, 0)))
    end, "Dummy")
end

function Gui.Indent(W)
    SafeCall(function()
        if W then ImGui.Indent(ValidateDimension(W, 500, 0)) else ImGui.Indent() end
    end, "Indent")
end

function Gui.Unindent(W)
    SafeCall(function()
        if W then ImGui.Unindent(ValidateDimension(W, 500, 0)) else ImGui.Unindent() end
    end, "Unindent")
end

function Gui.IconText(IconName, Text)
    return string.format("%s %s", Icon(IconName) or "", tostring(Text or ""))
end

function Gui.Text(Text)
    SafeCall(function()
        ImGui.Text(tostring(Text or ""))
    end, "Text")
end

function Gui.TextWrapped(Text)
    SafeCall(function()
        ImGui.TextWrapped(tostring(Text or ""))
    end, "TextWrapped")
end

function Gui.TextUnformatted(Text)
    SafeCall(function()
        ImGui.TextUnformatted(tostring(Text or ""))
    end, "TextUnformatted")
end

function Gui.TextDisabled(Text)
    SafeCall(function()
        ImGui.TextDisabled(tostring(Text or ""))
    end, "TextDisabled")
end

function Gui.TextColored(Color, Text)
    SafeCall(function()
        ImGui.TextColored(Color or ImVec4(1, 1, 1, 1), tostring(Text or ""))
    end, "TextColored")
end

function Gui.BulletText(Text)
    SafeCall(function()
        ImGui.BulletText(tostring(Text or ""))
    end, "BulletText")
end

function Gui.Tooltip(Text)
    SafeCall(function()
        if Text and ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.TextUnformatted(tostring(Text))
            ImGui.EndTooltip()
        end
    end, "Tooltip")
end

function Gui.HelpMarker(Text, NoSameLine)
    SafeCall(function()
        if not NoSameLine then Gui.SameLine() end
        Gui.TextDisabled(Icon("Info") or "?")
        Gui.Tooltip(Text)
    end, "HelpMarker")
end

--> Push/Pop Helpers

function Gui.WithItemWidth(Width, BodyFn)
    SafeCall(function()
        ImGui.PushItemWidth(ValidateDimension(Width, 9999, 0))
        GuiState.ItemWidthPushCount = GuiState.ItemWidthPushCount + 1
        SafeCall(BodyFn, "WithItemWidth.Body")
        ImGui.PopItemWidth()
        GuiState.ItemWidthPushCount = math.max(0, GuiState.ItemWidthPushCount - 1)
    end, "WithItemWidth")
end

function Gui.WithStyleVar(Var, Value, BodyFn)
    SafeCall(function()
        ImGui.PushStyleVar(Var, Value)
        GuiState.StylePushCount = GuiState.StylePushCount + 1
        SafeCall(BodyFn, "WithStyleVar.Body")
        ImGui.PopStyleVar()
        GuiState.StylePushCount = math.max(0, GuiState.StylePushCount - 1)
    end, "WithStyleVar")
end

function Gui.WithStyleColor(Idx, Color, BodyFn)
    SafeCall(function()
        ImGui.PushStyleColor(Idx, Color)
        GuiState.ColorPushCount = GuiState.ColorPushCount + 1
        SafeCall(BodyFn, "WithStyleColor.Body")
        ImGui.PopStyleColor()
        GuiState.ColorPushCount = math.max(0, GuiState.ColorPushCount - 1)
    end, "WithStyleColor")
end

function Gui.WithID(Id, BodyFn)
    SafeCall(function()
        ImGui.PushID(tostring(Id or ""))
        GuiState.IdPushCount = GuiState.IdPushCount + 1
        SafeCall(BodyFn, "WithID.Body")
        ImGui.PopID()
        GuiState.IdPushCount = math.max(0, GuiState.IdPushCount - 1)
    end, "WithID")
end

function Gui.Group(BodyFn)
    SafeCall(function()
        ImGui.BeginGroup()
        GuiState.GroupDepth = GuiState.GroupDepth + 1
        SafeCall(BodyFn, "Group.Body")
        ImGui.EndGroup()
        GuiState.GroupDepth = math.max(0, GuiState.GroupDepth - 1)
    end, "Group")
end

--> Layout Helpers

function Gui.ProgressBar(Value, Size, Overlay)
    SafeCall(function()
        local Fraction = tonumber(Value) or 0.0
        if Fraction < 0 then Fraction = 0 end
        if Fraction > 1 then Fraction = 1 end
    
        local BarSize = Size
        if BarSize == nil then
            local Avail = ImGui.GetContentRegionAvail()
            BarSize = ImVec2(Avail.x, 0)
        end
    
        local Label = Overlay
        if Label == nil then
            Label = string.format("%d%%", math.floor((Fraction * 100) + 0.5))
        end
    
        ImGui.ProgressBar(Fraction, BarSize, Label)
    end, "ProgressBar")
end

function Gui.ProgressBarFullWidth(Value, Height, Overlay)
    SafeCall(function()
        local Avail = ImGui.GetContentRegionAvail()
        Gui.ProgressBar(Value, ImVec2(Avail.x, tonumber(Height) or 0), Overlay)
    end, "ProgressBarFullWidth")
end

function Gui.IsAllEnabledFromLists(Lists)
    if not Cheats then return false end
    for _, List in ipairs(Lists or {}) do
        if type(List) == "table" then
            for _, Name in ipairs(List) do
                if type(Name) == "string" and not Cheats[Name] then
                    return false
                end
            end
        end
    end
    return true
end

function Gui.SetAllFromLists(Lists, Enable)
    SafeCall(function()
        if not Cheats then return end
        for _, List in ipairs(Lists or {}) do
            if type(List) == "table" then
                for _, Name in ipairs(List) do
                    if type(Name) == "string" then
                        Cheats[Name] = (Enable == true)
                    end
                end
            end
        end
    end, "SetAllFromLists")
end

function Gui.LabeledRow(Label, ControlFn, LabelWidth, ControlWidth)
    SafeCall(function()
        local LW = tonumber(LabelWidth) or 140
        Gui.AlignText()
        ImGui.Text(tostring(Label or ""))
        Gui.SameLine()
        if LW > 0 then ImGui.SetCursorPosX(ImGui.GetCursorPosX() + LW) end
        if ControlWidth then ImGui.PushItemWidth(ControlWidth); GuiState.ItemWidthPushCount = GuiState.ItemWidthPushCount + 1 end
        SafeCall(ControlFn, "LabeledRow.Control")
        if ControlWidth then ImGui.PopItemWidth(); GuiState.ItemWidthPushCount = math.max(0, GuiState.ItemWidthPushCount - 1) end
    end, "LabeledRow")
end

function Gui.Child(Id, Size, Border, BodyFn)
    SafeCall(function()
        if not Id then Id = "##ChildDefault" end
        local Width = 0
        local Height = 0
        
        if type(Size) == "number" then
            Width, Height = Size, 0
        elseif type(Size) == "table" and Size.x then
            Width, Height = Size.x, Size.y
        end
        
        Width, Height = ValidateChildSize(Width, Height)
        
        local Open = ImGui.BeginChild(tostring(Id), ImVec2(Width, Height), Border == true)
        if Open then
            GuiState.ChildDepth = GuiState.ChildDepth + 1
            local Success, Err = pcall(function()
                if type(BodyFn) == "function" then
                    BodyFn()
                end
            end)
            if not Success then
                Log("Child body error: " .. tostring(Err), "Error")
            end
            ImGui.EndChild()  -- PENTING: Selalu EndChild!
            GuiState.ChildDepth = math.max(0, GuiState.ChildDepth - 1)
        end
        return Open
    end, "Child")
end

function Gui.Columns(Count, Id, Border, BodyFn)
    SafeCall(function()
        ImGui.Columns(Count, Id or "##Cols", Border == true)
        SafeCall(BodyFn, "Columns.Body")
        ImGui.Columns(1)
    end, "Columns")
end

function Gui.TwoColumns(Id, LeftFn, RightFn, Border)
    SafeCall(function()
        Gui.Columns(2, Id or "##TwoCols", Border, function()
            SafeCall(LeftFn, "TwoColumns.Left")
            ImGui.NextColumn()
            SafeCall(RightFn, "TwoColumns.Right")
        end)
    end, "TwoColumns")
end

function Gui.Spinner(IconName, Speed)
    SafeCall(function()
        local S = tonumber(Speed) or 8.0
        local T = (ImGui.GetTime and ImGui.GetTime() or os.clock())
        local Phase = math.floor((T * S) % 4)
        local Frames = { "|", "/", "-", "\\" }
        Gui.TextDisabled(Gui.IconText(IconName, Frames[Phase + 1]))
    end, "Spinner")
end

--> Buttons / Toggles

function Gui.TwoButtons(LeftLabel, RightLabel, Height, Gap, OnLeft, OnRight)
    SafeCall(function()
        local H = tonumber(Height) or 23
        local G = tonumber(Gap) or 10
        local AvailW = ImGui.GetContentRegionAvail().x
        if AvailW < 50 then AvailW = 50 end
        local BtnW = (AvailW - G) * 0.5
        if BtnW < 10 then BtnW = 10 end
        
        Gui.Button(LeftLabel, ImVec2(BtnW, H), OnLeft)
        ImGui.SameLine(0, G)
        Gui.Button(RightLabel, ImVec2(BtnW, H), OnRight)
    end, "TwoButtons")
end

function Gui.ToggleAllButton(Lists, OnLabel, OffLabel, Size, OnToggle)
    SafeCall(function()
        local AllEnabled = Gui.IsAllEnabledFromLists(Lists)
        local Label = (AllEnabled and Icon("ToggleOff") or Icon("ToggleOn")) .. " " .. 
                      (AllEnabled and (OffLabel or "Disable All") or (OnLabel or "Enable All"))
        
        Gui.Button(Label, Size or ImVec2(0, 23), function()
            local Enable = not AllEnabled
            if type(OnToggle) == "function" then
                OnToggle(Enable, AllEnabled)
            else
                Gui.SetAllFromLists(Lists, Enable)
            end
        end)
        
        return AllEnabled
    end, "ToggleAllButton")
end

function Gui.Button(Label, Size, OnClick, TooltipText)
    local Result = false
    SafeCall(function()
        local W, H = 0, 0
        if type(Size) == "table" then
            W, H = ValidateDimension(Size.x, 9999, 0), ValidateDimension(Size.y, 9999, 0)
        end
        
        if ImGui.Button(Label, ImVec2(W, H)) then
            SafeCall(OnClick, "Button.OnClick")
            Result = true
        end
        Gui.Tooltip(TooltipText)
    end, "Button")
    return Result
end

function Gui.SmallButton(Label, OnClick, TooltipText)
    local Result = false
    SafeCall(function()
        if ImGui.SmallButton(Label) then
            SafeCall(OnClick, "SmallButton.OnClick")
            Result = true
        end
        Gui.Tooltip(TooltipText)
    end, "SmallButton")
    return Result
end

function Gui.IconButton(IconName, IdSuffix, Size, TooltipText, OnClick)
    local Label = (Icon(IconName) or "") .. "##" .. tostring(IdSuffix or IconName)
    return Gui.Button(Label, Size or ImVec2(0, 0), OnClick, TooltipText)
end

function Gui.Toggle(Label, StateTable, Key, TooltipText)
    local Changed, Val = false, false
    SafeCall(function()
        Changed, Val = ImGui.Checkbox(Label, StateTable[Key] == true)
        if Changed then StateTable[Key] = Val end
        Gui.Tooltip(TooltipText)
    end, "Toggle")
    return Changed, Val
end

function Gui.Radio(Label, StateTable, Key, Value, TooltipText)
    local Result, ResVal = false, StateTable[Key]
    SafeCall(function()
        local Selected = (StateTable[Key] == Value)
        if ImGui.RadioButton(Label, Selected) then
            StateTable[Key] = Value
            Result = true
            ResVal = Value
        end
        Gui.Tooltip(TooltipText)
    end, "Radio")
    return Result, ResVal
end

function Gui.WorldButton(Label, Size, RequiresWorld, OnClick, TipTitle, TipDesc)
    local Clicked, CanClick = false, true
    SafeCall(function()
        local NeedWorld = (RequiresWorld == true)
        CanClick = (not NeedWorld) or (GetWorld() ~= nil)

        if not CanClick then ImGui.BeginDisabled(); GuiState.DisabledDepth = GuiState.DisabledDepth + 1 end
        Clicked = Gui.Button(Label, Size or ImVec2(0, 23), OnClick)
        if not CanClick then
            ImGui.EndDisabled()
            GuiState.DisabledDepth = math.max(0, GuiState.DisabledDepth - 1)

            ImGui.SetCursorScreenPos(ImGui.GetItemRectMin())
            ImGui.InvisibleButton("##WorldHover_" .. tostring(Label), ImGui.GetItemRectSize())
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.TextColored(ImVec4(1.0, 0.8, 0.2, 1.0), tostring(TipTitle or (Icon("Exclamation") .. " World Required")))
                ImGui.Separator()
                ImGui.Text(tostring(TipDesc or "This feature requires you to be inside a Growtopia world."))
                ImGui.EndTooltip()
            end
        end
    end, "WorldButton")
    return Clicked, CanClick
end

function Gui.Checkbox(Label, Value, OnChange, TooltipText)
    local Changed, NewValue = false, Value
    SafeCall(function()
        Changed, NewValue = ImGui.Checkbox(tostring(Label or ""), Value == true)
        if Changed and type(OnChange) == "function" then
            OnChange(NewValue)
        end
        Gui.Tooltip(TooltipText)
    end, "Checkbox")
    return Changed, NewValue
end

function Gui.ToggleKey(Label, StateTable, Key, TooltipText, OnChange)
    local Changed, NewValue = false, false
    SafeCall(function()
        if type(StateTable) ~= "table" then return false, false end
        local Current = (StateTable[Key] == true)
        Changed, NewValue = ImGui.Checkbox(tostring(Label or ""), Current)
        if Changed then
            StateTable[Key] = NewValue
            if type(OnChange) == "function" then OnChange(NewValue) end
        end
        Gui.Tooltip(TooltipText)
    end, "ToggleKey")
    return Changed, NewValue
end

function Gui.CheatToggle(OptionName, TooltipText, OnChange)
    local Changed, NewValue = false, false
    SafeCall(function()
        if not Cheats or type(OptionName) ~= "string" then return false, false end
        Changed, NewValue = ImGui.Checkbox(OptionName, Cheats[OptionName] == true)
        if Changed then
            Cheats[OptionName] = NewValue
            if type(OnChange) == "function" then OnChange(NewValue) end
        end
        Gui.Tooltip(TooltipText)
    end, "CheatToggle")
    return Changed, NewValue
end

function Gui.CheatRadioGroup(OptionList, SelectedName, TooltipText)
    local ChangedAny = false
    SafeCall(function()
        if not Cheats or type(OptionList) ~= "table" then return false, SelectedName end
        for _, Name in ipairs(OptionList) do
            if type(Name) == "string" then
                local Current = (Cheats[Name] == true)
                local Changed, NewValue = ImGui.Checkbox(Name, Current)
                if Changed then
                    for _, Other in ipairs(OptionList) do
                        if type(Other) == "string" then Cheats[Other] = false end
                    end
                    Cheats[Name] = NewValue
                    ChangedAny = true
                    SelectedName = (NewValue and Name) or SelectedName
                end
                Gui.Tooltip(TooltipText)
            end
        end
    end, "CheatRadioGroup")
    return ChangedAny, SelectedName
end

--> Inputs

function Gui.InputText(Label, StateTable, Key, MaxLen, Flags, TooltipText)
    return Gui.InputTextKey(Label, StateTable, Key, MaxLen or 256, nil, Flags, TooltipText)
end

function Gui.InputInt(Label, StateTable, Key, Step, StepFast, Flags, TooltipText)
    local Changed, Val = false, 0
    SafeCall(function()
        Changed, Val = ImGui.InputInt(Label, tonumber(StateTable[Key] or 0), Step or 1, StepFast or 10, Flags or 0)
        if Changed then StateTable[Key] = Val end
        Gui.Tooltip(TooltipText)
    end, "InputInt")
    return Changed, Val
end

function Gui.InputFloat(Label, StateTable, Key, Step, StepFast, Format, Flags, TooltipText)
    local Changed, Val = false, 0
    SafeCall(function()
        Changed, Val = ImGui.InputFloat(Label, tonumber(StateTable[Key] or 0), Step or 0.1, StepFast or 1.0, Format or "%.3f", Flags or 0)
        if Changed then StateTable[Key] = Val end
        Gui.Tooltip(TooltipText)
    end, "InputFloat")
    return Changed, Val
end

function Gui.SliderInt(Label, StateTable, Key, Min, Max, Format, Flags, TooltipText)
    local Changed, Val = false, 0
    SafeCall(function()
        Changed, Val = ImGui.SliderInt(Label, tonumber(StateTable[Key] or 0), Min or 0, Max or 100, Format, Flags or 0)
        if Changed then StateTable[Key] = Val end
        Gui.Tooltip(TooltipText)
    end, "SliderInt")
    return Changed, Val
end

function Gui.SliderFloat(Label, StateTable, Key, Min, Max, Format, Flags, TooltipText)
    local Changed, Val = false, 0
    SafeCall(function()
        Changed, Val = ImGui.SliderFloat(Label, tonumber(StateTable[Key] or 0), Min or 0, Max or 1, Format or "%.3f", Flags or 0)
        if Changed then StateTable[Key] = Val end
        Gui.Tooltip(TooltipText)
    end, "SliderFloat")
    return Changed, Val
end

function Gui.ClampIntInput(Label, StateTable, Key, Min, Max, Step, StepFast, TooltipText)
    SafeCall(function()
        if type(StateTable) ~= "table" then return false, 0 end
        local Current = tonumber(StateTable[Key] or 0) or 0
        local Changed, NewValue = ImGui.InputInt(Label, Current, Step or 1, StepFast or 5)
        
        if ImGui.IsItemActive() and Max and NewValue > Max then
            ImGui.BeginTooltip()
            ImGui.TextColored(ImVec4(1.0, 0.3, 0.3, 1.0), (Icon("Ban") or "!") .. " Maximum value is " .. tostring(Max) .. "!")
            ImGui.EndTooltip()
        else
            Gui.Tooltip(TooltipText)
        end
        
        if Changed then
            if Min ~= nil then NewValue = math.max(Min, NewValue) end
            if Max ~= nil then NewValue = math.min(Max, NewValue) end
            StateTable[Key] = NewValue
        end
        return Changed, StateTable[Key]
    end, "ClampIntInput")
end

--> Select / Combo

function Gui.Combo(Label, StateTable, Key, Items, TooltipText)
    local Changed = false
    SafeCall(function()
        local Current = tostring(StateTable[Key] or "")
        local Preview = Current ~= "" and Current or (Items and Items[1]) or ""
        
        if ImGui.BeginCombo(Label, Preview) then
            for _, It in ipairs(Items or {}) do
                local IsSelected = (Current == It)
                if ImGui.Selectable(It, IsSelected) then
                    StateTable[Key] = It
                    Changed = true
                end
                if IsSelected then ImGui.SetItemDefaultFocus() end
            end
            ImGui.EndCombo()
        end
        Gui.Tooltip(TooltipText)
    end, "Combo")
    return Changed, StateTable[Key]
end

function Gui.ComboIndex(Label, StateTable, Key, Items, TooltipText)
    local Changed = false
    SafeCall(function()
        local Idx = tonumber(StateTable[Key] or 1)
        if Idx < 1 then Idx = 1 end
        local Preview = tostring((Items or {})[Idx] or "")
        
        if ImGui.BeginCombo(Label, Preview) then
            for i, It in ipairs(Items or {}) do
                local IsSelected = (Idx == i)
                if ImGui.Selectable(tostring(It), IsSelected) then
                    StateTable[Key] = i
                    Changed = true
                end
                if IsSelected then ImGui.SetItemDefaultFocus() end
            end
            ImGui.EndCombo()
        end
        Gui.Tooltip(TooltipText)
    end, "ComboIndex")
    return Changed, StateTable[Key]
end

function Gui.Selectable(Label, Selected, OnClick, TooltipText)
    local Result = false
    SafeCall(function()
        if ImGui.Selectable(Label, Selected == true) then
            SafeCall(OnClick, "Selectable.OnClick")
            Result = true
        end
        Gui.Tooltip(TooltipText)
    end, "Selectable")
    return Result
end

--> Colors

function Gui.ColorEdit4(Label, StateTable, Key, Flags, TooltipText)
    local Changed = false
    SafeCall(function()
        local V = StateTable[Key]
        if type(V) ~= "table" then V = {1, 1, 1, 1} end
        Changed, R, G, B, A = ImGui.ColorEdit4(Label, V[1], V[2], V[3], V[4], Flags or 0)
        if Changed then
            StateTable[Key] = {R, G, B, A}
        end
        Gui.Tooltip(TooltipText)
    end, "ColorEdit4")
    return Changed, StateTable[Key]
end

function Gui.ColorButton(Label, Color, Size, TooltipText)
    SafeCall(function()
        ImGui.ColorButton(Label, Color or ImVec4(1, 1, 1, 1), 0, Size or ImVec2(20, 20))
        Gui.Tooltip(TooltipText)
    end, "ColorButton")
end

--> Tabs / Trees / Tables

function Gui.TabBar(Id, Tabs)
    local Result = false
    SafeCall(function()
        if not Id then Id = "##TabBarDefault" end
        if not ImGui.BeginTabBar(tostring(Id)) then return false end
        
        for _, T in ipairs(Tabs or {}) do
            if T and T.Label then
                local Label = tostring(T.Label)
                local Flags = T.Flags or 0
                if ImGui.BeginTabItem(Label, nil, Flags) then
                    local Success, Err = pcall(T.Draw, T)
                    if not Success then
                        Log("TabBar draw error: " .. tostring(Err), "Error")
                    end
                    ImGui.EndTabItem()
                end
            end
        end
        
        ImGui.EndTabBar()  -- PENTING: Jangan lupa ini!
        Result = true
    end, "TabBar")
    return Result
end

function Gui.TreeNode(Label, BodyFn, Flags)
    local Open = false
    SafeCall(function()
        Open = ImGui.TreeNodeEx(Label, Flags or 0)
        if Open then
            SafeCall(BodyFn, "TreeNode.Body")
            ImGui.TreePop()
        end
    end, "TreeNode")
    return Open
end

function Gui.Table(Id, ColumnCount, Flags, OuterSize, InnerWidth, HeaderFn, RowFn)
    local Result = false
    SafeCall(function()
        if ImGui.BeginTable(Id, ColumnCount, Flags or 0, OuterSize or ImVec2(0, 0), InnerWidth or 0) then
            if HeaderFn then SafeCall(HeaderFn, "Table.Header") end
            if RowFn then SafeCall(RowFn, "Table.Row") end
            ImGui.EndTable()
            Result = true
        end
    end, "Table")
    return Result
end

function Gui.TableHeaders(Headers)
    SafeCall(function()
        for _, H in ipairs(Headers or {}) do
            ImGui.TableSetupColumn(tostring(H))
        end
        ImGui.TableHeadersRow()
    end, "TableHeaders")
end

--> Popups / Modals

function Gui.Popup(Id, BodyFn)
    local Result = false
    SafeCall(function()
        if ImGui.BeginPopup(Id) then
            SafeCall(BodyFn, "Popup.Body")
            ImGui.EndPopup()
            Result = true
        end
    end, "Popup")
    return Result
end

function Gui.OpenPopup(Id)
    SafeCall(function()
        ImGui.OpenPopup(Id)
    end, "OpenPopup")
end

function Gui.Modal(Id, BodyFn, Flags)
    local Result = false
    SafeCall(function()
        local Open = true
        if ImGui.BeginPopupModal(Id, Open, Flags or 0) then
            SafeCall(BodyFn, "Modal.Body")
            ImGui.EndPopup()
            Result = true
        end
    end, "Modal")
    return Result
end

--> Toolbar

function Gui.Toolbar(Items, DefaultH)
    SafeCall(function()
        local H = DefaultH or 23
        for i, It in ipairs(Items or {}) do
            if i > 1 then Gui.SameLine() end
            local T = It.Type or "Button"
            
            if T == "Button" then
                local W = It.W or 80
                Gui.Button(It.Label or "Button", ImVec2(W, It.H or H), It.OnClick, It.Tip)
            elseif T == "SmallButton" then
                Gui.SmallButton(It.Label or "Button", It.OnClick, It.Tip)
            elseif T == "TextDisabled" then
                Gui.TextDisabled(It.Text or "")
            elseif T == "TextColored" then
                Gui.TextColored(It.Color or ImVec4(1, 1, 1, 1), It.Text or "")
            elseif T == "Text" then
                Gui.Text(It.Text or "")
            elseif T == "Spacing" then
                Gui.Spacing(It.N or 1)
            elseif T == "Separator" then
                ImGui.Separator()
            end
        end
    end, "Toolbar")
end

--> Error Status Functions

function Gui.GetErrorStatus()
    return {
        LastError = GuiState.LastError,
        ErrorCount = GuiState.ErrorCount,
        ChildDepth = GuiState.ChildDepth,
        WindowDepth = GuiState.WindowDepth,
        GroupDepth = GuiState.GroupDepth,
        DisabledDepth = GuiState.DisabledDepth,
        ColorPushCount = GuiState.ColorPushCount,
        StylePushCount = GuiState.StylePushCount
    }
end

function Gui.RecoverStack()
    if GuiState.ChildDepth > 0 or GuiState.WindowDepth > 0 or GuiState.GroupDepth > 0 then
        if Console then
            Console("[`6Gui Recovery`o] Cleaning up ImGui stack...", "Warning")
        end
        CleanupGuiStack()
        return true
    end
    return false
end

--> Close

--> Helper Functions

function IsAllEnabledFromLists(Lists)
    for _, L in ipairs(Lists or {}) do
        for _, Name in ipairs(L or {}) do
            if type(Name) == "string" and not Cheats[Name] then
                return false
            end
        end
    end
    return true
end

function ToggleAllMapped(Lists, Enable, Mapping)
    for _, L in ipairs(Lists or {}) do
        for _, Name in ipairs(L or {}) do
            if type(Name) == "string" then
                Cheats[Name] = Enable
                local Key = Mapping and Mapping[Name]
                if Key and ChangeValue then
                    ChangeValue(Key, Enable)
                end
            end
        end
    end
end

function ResolveMethod(Self, CleanName)
    local Method = Self and Self[CleanName]
    if type(Method) == "function" then
        return function() Method(Self) end
    end
    return nil
end --> Resolve method

function DrawSubTabs(Self, TabBarId, SubTabsList, DefaultTitle)
    SubTabsList = SubTabsList or {}
    Gui.TabBar(TabBarId, Gui.BuildTabs(
        SubTabsList,
        DefaultTitle,
        function(CleanName) return ResolveMethod(Self, CleanName) end,
        function() DrawBlank(nil, "Secondary") end
    ))
end
--> Draw Sub Tabs easily

function CleanTabLabel(Label)
    return tostring(Label or "")
        :gsub("^[^\x20-\x7E]+", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end --> Clean label from non-printable prefix + trim spaces

function DrawSubTabRoot(TabId, Title, BodyFn)
    if Gui.Header then
        Gui.Header(Title)
    else
        Gui.Text(Title); Gui.Separator()
    end
    return BodyFn()
end --> Draw a sub-tab root title/header then run BodyFn

function DrawPanel(PanelId, Title, Height, BodyFn)
    return Gui.Child(PanelId, ImVec2(0, Height or 207), true, function()
        if Gui.Header then
            Gui.Header(Title)
        else
            Gui.Text(Title); Gui.Separator()
        end
        BodyFn()
    end)
end --> Draw a titled child panel with fixed height and BodyFn content

function WorldRequiredButton(Label, Size, IsAllowed, OnClick, TipTitle, TipDesc)
    if not IsAllowed then ImGui.BeginDisabled() end
    local WasClicked = Gui.Button(Label, Size or ImVec2(0, 23), OnClick)
    if IsAllowed then return WasClicked end

    ImGui.EndDisabled()
    ImGui.SetCursorScreenPos(ImGui.GetItemRectMin())
    ImGui.InvisibleButton("##Hover_" .. Label, ImGui.GetItemRectSize())

    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.TextColored(ImVec4(1.0, 0.8, 0.2, 1.0), TipTitle or "World Required")
        ImGui.Separator()
        ImGui.Text(tostring(TipDesc or "This feature requires you to be inside a Growtopia world."))
        ImGui.EndTooltip()
    end

    return WasClicked
end --> Button that disables itself when not allowed, with hover tooltip explaining requirement

--> Close

--> Renderer

function DrawTwoPanelMappedTab(Spec)
    local Data = Spec.Data()
    if not Data then return end

    DrawSubTabRoot("##"..Spec.Id, Spec.Title, function()
        ImGui.Columns(2, "##"..Spec.Id.."Cols", false)

        -- LEFT PANEL
        if ImGui.BeginChild("##"..Spec.Id.."Main", ImVec2(0, 207), true) then
            if Gui.Header then
                Gui.Header(Spec.LeftTitle)
            else
                Gui.Text(Spec.LeftTitle)
                Gui.Separator()
            end
            for _, Name in ipairs(Data.Feature or {}) do
                local Success, Err = pcall(function()
                    Gui.CheatToggleMapped(Name, Spec.Mapping and Spec.Mapping[Name])
                end)
                if not Success then Log("CheatToggle error: " .. tostring(Err), "Error") end
            end
            ImGui.EndChild()
        end

        ImGui.NextColumn()

        -- RIGHT PANEL
        if ImGui.BeginChild("##"..Spec.Id.."More", ImVec2(0, 207), true) then
            if Gui.Header then
                Gui.Header(Spec.RightTitle)
            else
                Gui.Text(Spec.RightTitle)
                Gui.Separator()
            end
            for _, Name in ipairs(Data.More or {}) do
                local Success, Err = pcall(function()
                    Gui.CheatToggleMapped(Name, Spec.Mapping and Spec.Mapping[Name])
                end)
                if not Success then Log("CheatToggle error: " .. tostring(Err), "Error") end
            end
            ImGui.EndChild()
        end

        ImGui.Columns(1)  -- Tutup columns

        -- FOOTER
        Gui.Spacing()
        if ImGui.BeginChild("##"..Spec.Id.."Footer", ImVec2(0, 0), true) then
            Gui.Header(Icon("Asterisk") .. " Quick Controls:")
            
            local AllEnabled = IsAllEnabledFromLists({ Data.Feature, Data.More })
            local Enable = not AllEnabled

            Gui.Button(
                (AllEnabled and Icon("ToggleOff") or Icon("ToggleOn")) ..
                (Enable and " Enable All" or " Disable All"),
                ImVec2(0, 23),
                function()
                    RunThread(function()
                        ToggleAllMapped({ Data.Feature, Data.More }, Enable, Spec.Mapping)
                    end)
                end
            )

            if Spec.ExtraFooter then
                Gui.SameLine()
                local Success, Err = pcall(Spec.ExtraFooter, Data)
                if not Success then Log("ExtraFooter error: " .. tostring(Err), "Error") end
            end
            
            ImGui.EndChild()
        end
    end)
end

function DrawTwoPanelSlots(Spec)
    if not Spec then return end
    
    local Id = tostring(Spec.Id or "TwoPanel")
    local Title = tostring(Spec.Title or "Untitled")

    local L = Spec.Left or {}
    local R = Spec.Right or {}

    DrawSubTabRoot("##" .. Id .. "Root", Title, function()
        -- Gunakan Columns dengan proper nesting
        ImGui.Columns(2, "##" .. Id .. "Cols", false)
        
        -- LEFT PANEL
        if ImGui.BeginChild("##" .. (L.Id or (Id .. "Left")), ImVec2(0, L.Height or 207), true) then
            if Gui.Header then
                Gui.Header(L.Title or "")
            else
                Gui.Text(L.Title or "")
                Gui.Separator()
            end
            if type(L.BodyFn) == "function" then 
                local Success, Err = pcall(L.BodyFn)
                if not Success then Log("Left panel error: " .. tostring(Err), "Error") end
            end
            ImGui.EndChild()
        end

        ImGui.NextColumn()

        -- RIGHT PANEL
        if ImGui.BeginChild("##" .. (R.Id or (Id .. "Right")), ImVec2(0, R.Height or 207), true) then
            if Gui.Header then
                Gui.Header(R.Title or "")
            else
                Gui.Text(R.Title or "")
                Gui.Separator()
            end
            if type(R.BodyFn) == "function" then 
                local Success, Err = pcall(R.BodyFn)
                if not Success then Log("Right panel error: " .. tostring(Err), "Error") end
            end
            ImGui.EndChild()
        end

        ImGui.Columns(1)  -- Tutup columns

        -- FOOTER
        if Spec.Footer and type(Spec.Footer.BodyFn) == "function" then
            Gui.Spacing()
            if ImGui.BeginChild("##" .. (Spec.Footer.Id or (Id .. "Footer")), ImVec2(0, 0), true) then
                Gui.Header(Icon("Asterisk") .. " Quick Controls:")
                local Success, Err = pcall(Spec.Footer.BodyFn)
                if not Success then Log("Footer error: " .. tostring(Err), "Error") end
                ImGui.EndChild()
            end
        end
    end)
end

--> Close
