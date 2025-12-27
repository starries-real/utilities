--> ImGui Builder with Error Handler Support

    Gui = Gui or {}

    local function SafeCall(Fn, Where, ...)
        if type(Fn) ~= "function" then return end
        
        -- Gunakan ProtectFunction dari error handler jika tersedia
        if ProtectFunction then
            local ProtectedFn = ProtectFunction(Fn, Where or "Gui:SafeCall", function(...)
                if Console then Console("SafeCall Fallback: " .. Where, "Warning") end
                return nil
            end, {
                DebugMode = false
            })
            return ProtectedFn(...)
        else
            -- Fallback jika ProtectFunction belum loaded
            local Ok, Err = pcall(Fn, ...)
            if not Ok then
                if Console then Console("UI Error (" .. Where .. "): " .. tostring(Err), "Error") end
            end
        end
    end

    --> Basic

        function Gui.Paragraph(Text, Width, Indent)
            Indent = Indent or 6
            Gui.Indent(Indent)
            ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + (Width or 260))
            Gui.TextWrapped(tostring(Text or ""))
            ImGui.PopTextWrapPos()
            Gui.Unindent(Indent)
        end

        function Gui.RadioGroupKey(Options, StateTable, Key, IdSuffix)
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
        end

        function Gui.InputTextKey(Label, StateTable, Key, MaxLen, Width, Flags)
            if type(StateTable) ~= "table" or not Key then return false, "" end
                StateTable[Key] = tostring(StateTable[Key] or "")
                local Buffer = StateTable[Key]
                    if Width then ImGui.PushItemWidth(Width) end
                    local Changed, NewText = ImGui.InputText(
                        Label,
                        Buffer,
                        MaxLen or 256,
                        Flags or 0
                    )
                if Width then ImGui.PopItemWidth() end
                if Changed then StateTable[Key] = NewText end
            return Changed, StateTable[Key]
        end

        function Gui.RowButtons(Buttons, DefaultSize)
            for Index, Btn in ipairs(Buttons or {}) do
                if Index > 1 then
                    Gui.SameLine()
                end

                local Size = Btn.Size or DefaultSize or ImVec2(0, 23)
                Gui.Button(
                    tostring(Btn.Label or "Button"),
                    Size,
                    Btn.OnClick,
                    Btn.Tooltip,
                    "Gui:RowButtons:Btn_" .. tostring(Index)
                )
            end
        end

        function Gui.ToggleCheatNames(Names, ConfigMapping)
            for _, OptionName in ipairs(Names or {}) do
                if Cheats and Cheats[OptionName] ~= nil then
                    local NewValue = not Cheats[OptionName]
                    Cheats[OptionName] = NewValue

                    local ConfigKey = ConfigMapping and ConfigMapping[OptionName]
                    if ConfigKey and ChangeValue then
                        ChangeValue(ConfigKey, NewValue)
                    end
                end
            end
        end

        function Gui.CheatToggleMapped(OptionName, ConfigKey, TooltipText)
            if type(OptionName) ~= "string" then
                return false, false
            end
        
            local CurrentValue = false
        
            if ConfigKey and GetValue then
                if OptionName == "Anti Lag" then
                    local Particle = (GetValue("[C] No render particle") or false) == true
                    local Shadow   = (GetValue("[C] No render shadow") or false) == true
                    local Name     = (GetValue("[C] No render name") or false) == true
                    CurrentValue = (Particle and Shadow and Name)
                else
                    CurrentValue = (GetValue(ConfigKey) or false) == true
                end
            else
                CurrentValue = (Cheats and Cheats[OptionName] == true) or false
            end
        
            local Changed, NewValue = ImGui.Checkbox(OptionName, CurrentValue)
        
            if TooltipText and TooltipText ~= "" then
                if ImGui.IsItemHovered() then
                    Gui.Tooltip(TooltipText)
                end
            end
        
            if not Changed then
                return false, CurrentValue
            end
        
            if ConfigKey and ChangeValue then
                if OptionName == "Anti Lag" then
                    ChangeValue("[C] No render particle", NewValue)
                    ChangeValue("[C] No render shadow", NewValue)
                    ChangeValue("[C] No render name", NewValue)
                else
                    ChangeValue(ConfigKey, NewValue)
                end
            end
        
            if Cheats then
                Cheats[OptionName] = NewValue
            end
        
            return true, NewValue
        end

        function Gui.SetCheatListMapped(OptionList, Enable, ConfigMapping)
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
        end

        function Gui.CleanLabel(Label)
            return tostring(Label or "")
                :gsub("^[^\x20-\x7E]+", "")
                :gsub("^%s+", "")
                :gsub("%s+$", "")
        end

        function Gui.BuildTabs(Labels, IdPrefix, ResolveFn, FallbackFn)
            local Tabs = {}

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
                                DrawBlank(0.50, 2)
                            end
                        end, "Gui:BuildTabs:Tab_" .. CleanName)
                    end
                }
            end

            return Tabs
        end

        function Gui.Header(Text)
            ImGui.Text(tostring(Text or ""))
            Gui.Spacing(1)
            ImGui.Separator()
            Gui.Spacing(1)
        end


        function Gui.SubHeader(Text)
            Gui.TextDisabled(tostring(Text or ""))
            Gui.Separator()
        end

        function Gui.Spacing(Count)
            local N = tonumber(Count) or 1
            for _ = 1, N do ImGui.Spacing() end
        end

        function Gui.Separator()
            if DrawSeparator then
                DrawSeparator()
            else
                Gui.Spacing(1)
                ImGui.Separator()
                Gui.Spacing(1)
            end
        end

        function Gui.SameLine(OffsetX, Spacing)
            if OffsetX ~= nil or Spacing ~= nil then
                ImGui.SameLine(OffsetX or 0, Spacing or -1)
            else
                ImGui.SameLine()
            end
        end

        function Gui.AlignText()
            ImGui.AlignTextToFramePadding()
        end

        function Gui.Dummy(W, H)
            ImGui.Dummy(ImVec2(W or 0, H or 0))
        end

        function Gui.Indent(W)
            if W then ImGui.Indent(W) else ImGui.Indent() end
        end

        function Gui.Unindent(W)
            if W then ImGui.Unindent(W) else ImGui.Unindent() end
        end

        function Gui.IconText(IconName, Text)
            return string.format("%s %s", Icon(IconName), tostring(Text or ""))
        end

        function Gui.Text(Text)
            ImGui.Text(tostring(Text or ""))
        end

        function Gui.TextWrapped(Text)
            ImGui.TextWrapped(tostring(Text or ""))
        end

        function Gui.TextUnformatted(Text)
            ImGui.TextUnformatted(tostring(Text or ""))
        end

        function Gui.TextDisabled(Text)
            ImGui.TextDisabled(tostring(Text or ""))
        end

        function Gui.TextColored(Color, Text)
            ImGui.TextColored(Color or ImVec4(1, 1, 1, 1), tostring(Text or ""))
        end

        function Gui.BulletText(Text)
            ImGui.BulletText(tostring(Text or ""))
        end

        function Gui.Tooltip(Text)
            if Text and ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.TextUnformatted(tostring(Text))
                ImGui.EndTooltip()
            end
        end

        function Gui.HelpMarker(Text, NoSameLine)
            if not NoSameLine then Gui.SameLine() end
            Gui.TextDisabled(Icon("Info"))
            Gui.Tooltip(Text)
        end


    --> Close

    --> Push/Pop Helpers

        function Gui.WithItemWidth(Width, BodyFn)
            ImGui.PushItemWidth(Width or 0)
            SafeCall(BodyFn, "Gui:WithItemWidth")
            ImGui.PopItemWidth()
        end

        function Gui.WithStyleVar(Var, Value, BodyFn)
            ImGui.PushStyleVar(Var, Value)
            SafeCall(BodyFn, "Gui:WithStyleVar")
            ImGui.PopStyleVar()
        end

        function Gui.WithStyleColor(Idx, Color, BodyFn)
            ImGui.PushStyleColor(Idx, Color)
            SafeCall(BodyFn, "Gui:WithStyleColor")
            ImGui.PopStyleColor()
        end

        function Gui.WithID(Id, BodyFn)
            ImGui.PushID(tostring(Id or ""))
            SafeCall(BodyFn, "Gui:WithID:" .. tostring(Id))
            ImGui.PopID()
        end

        function Gui.Group(BodyFn)
            ImGui.BeginGroup()
            SafeCall(BodyFn, "Gui:Group")
            ImGui.EndGroup()
        end

    --> Close

    --> Layout Helpers

        function Gui.ProgressBar(Value, Size, Overlay)
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
        end

        function Gui.ProgressBarFullWidth(Value, Height, Overlay)
            local Avail = ImGui.GetContentRegionAvail()
            Gui.ProgressBar(Value, ImVec2(Avail.x, tonumber(Height) or 0), Overlay)
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
        end

        function Gui.LabeledRow(Label, ControlFn, LabelWidth, ControlWidth)
            local LW = LabelWidth or 140
            Gui.AlignText()

            ImGui.Text(tostring(Label or ""))
            Gui.SameLine()

            if LW > 0 then
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + LW)
            end

            if ControlWidth then ImGui.PushItemWidth(ControlWidth) end
            SafeCall(ControlFn, "Gui:LabeledRow:" .. tostring(Label))
            if ControlWidth then ImGui.PopItemWidth() end
        end


        function Gui.Child(Id, Size, Border, BodyFn, Location)
            local Open = ImGui.BeginChild(Id, Size or ImVec2(0, 0), Border == true)
            if Open then SafeCall(BodyFn, Location or "Gui:Child:" .. tostring(Id)) end
            ImGui.EndChild()
            return Open
        end

        function Gui.Columns(Count, Id, Border, BodyFn)
            ImGui.Columns(Count, Id or "##Cols", Border == true)
            SafeCall(BodyFn, "Gui:Columns:" .. tostring(Id))
            ImGui.Columns(1)
        end

        function Gui.TwoColumns(Id, LeftFn, RightFn, Border)
            Gui.Columns(2, Id or "##TwoCols", Border, function()
                SafeCall(LeftFn, "Gui:TwoColumns:" .. tostring(Id) .. ":Left")
                ImGui.NextColumn()
                SafeCall(RightFn, "Gui:TwoColumns:" .. tostring(Id) .. ":Right")
            end)
        end

        function Gui.Spinner(IconName, Speed)
            local S = tonumber(Speed) or 8.0
            local T = (ImGui.GetTime and ImGui.GetTime() or os.clock())
            local Phase = math.floor((T * S) % 4)
        
            local Frames = { "|", "/", "-", "\\" }
            Gui.TextDisabled(Gui.IconText(IconName, Frames[Phase + 1]))
        end
    
    --> Close

    --> Buttons / Toggles

        function Gui.TwoButtons(LeftLabel, RightLabel, Height, Gap, OnLeft, OnRight)
            local H = tonumber(Height) or 23
            local G = tonumber(Gap) or 10
        
            local AvailW = ImGui.GetContentRegionAvail().x
            if AvailW < 50 then AvailW = 50 end
        
            local BtnW = (AvailW - G) * 0.5
            if BtnW < 10 then BtnW = 10 end
        
            if Gui.Button(LeftLabel, ImVec2(BtnW, H), OnLeft, nil, "Gui:TwoButtons:Left") then end
            ImGui.SameLine(0, G)
            if Gui.Button(RightLabel, ImVec2(BtnW, H), OnRight, nil, "Gui:TwoButtons:Right") then end
        end

        function Gui.ToggleAllButton(Lists, OnLabel, OffLabel, Size, OnToggle)
            local AllEnabled = Gui.IsAllEnabledFromLists(Lists)
        
            local Label =
                (AllEnabled and Icon("ToggleOff") or Icon("ToggleOn")) ..
                " " ..
                (AllEnabled and (OffLabel or "Disable All") or (OnLabel or "Enable All"))
        
            Gui.Button(Label, Size or ImVec2(0, 23), function()
                local Enable = not AllEnabled
                if type(OnToggle) == "function" then
                    OnToggle(Enable, AllEnabled)
                else
                    Gui.SetAllFromLists(Lists, Enable)
                end
            end, nil, "Gui:ToggleAllButton")
        
            return AllEnabled
        end

        function Gui.Button(Label, Size, OnClick, TooltipText, Location)
            if ImGui.Button(Label, Size or ImVec2(0, 0)) then
                SafeCall(OnClick, Location or "Gui:Button:" .. tostring(Label))
                return true
            end
            Gui.Tooltip(TooltipText)
            return false
        end

        function Gui.SmallButton(Label, OnClick, TooltipText, Location)
            if ImGui.SmallButton(Label) then
                SafeCall(OnClick, Location or "Gui:SmallButton:" .. tostring(Label))
                return true
            end
            Gui.Tooltip(TooltipText)
            return false
        end

        function Gui.IconButton(IconName, IdSuffix, Size, TooltipText, OnClick)
            local Label = Icon(IconName) .. "##" .. tostring(IdSuffix or IconName)
            return Gui.Button(Label, Size or ImVec2(0, 0), OnClick, TooltipText, "Gui:IconButton:" .. tostring(IdSuffix))
        end

        function Gui.Toggle(Label, StateTable, Key, TooltipText)
            local Changed, Val = ImGui.Checkbox(Label, StateTable[Key] == true)
            if Changed then StateTable[Key] = Val end
            Gui.Tooltip(TooltipText)
            return Changed, Val
        end

        function Gui.Radio(Label, StateTable, Key, Value, TooltipText)
            local Selected = (StateTable[Key] == Value)
            if ImGui.RadioButton(Label, Selected) then
                StateTable[Key] = Value
                Gui.Tooltip(TooltipText)
                return true, Value
            end
            Gui.Tooltip(TooltipText)
            return false, StateTable[Key]
        end

        function Gui.WorldButton(Label, Size, IsDisabled, OnClick, TooltipText)
            local CanClick = not IsDisabled
            
            if not CanClick then 
                ImGui.BeginDisabled() 
            end
            
            local Clicked = Gui.Button(Label, Size or ImVec2(0, 23), OnClick, nil, "Gui:WorldButton:" .. tostring(Label))
            
            if not CanClick then
                ImGui.EndDisabled()
                
                if TooltipText and TooltipText ~= "" then
                    ImGui.SetCursorScreenPos(ImGui.GetItemRectMin())
                    ImGui.InvisibleButton("##WorldHover_" .. tostring(Label), ImGui.GetItemRectSize())
                    if ImGui.IsItemHovered() then
                        ImGui.BeginTooltip()
                        local lines = {}
                        for line in TooltipText:gmatch("[^\n]+") do
                            table.insert(lines, line)
                        end
                        
                        if #lines > 0 then
                            if lines[1]:find(Icon("Exclamation")) or lines[1]:find("World Required") then
                                ImGui.TextColored(ImVec4(1.0, 0.8, 0.2, 1.0), lines[1])
                            else
                                ImGui.Text(lines[1])
                            end
                        end
                        
                        for i = 2, #lines do
                            if i == 2 then ImGui.Separator() end
                            ImGui.Text(lines[i])
                        end
                        ImGui.EndTooltip()
                    end
                end
            end
            
            return Clicked, CanClick
        end

        function Gui.Checkbox(Label, Value, OnChange, TooltipText)
            local Changed, NewValue = ImGui.Checkbox(tostring(Label or ""), Value == true)
            if Changed and type(OnChange) == "function" then
                SafeCall(OnChange, "Gui:Checkbox:" .. tostring(Label), NewValue)
            end
            Gui.Tooltip(TooltipText)
            return Changed, NewValue
        end

        function Gui.ToggleKey(Label, StateTable, Key, TooltipText, OnChange)
            if type(StateTable) ~= "table" then return false, false end
            local Current = (StateTable[Key] == true)

            local Changed, NewValue = ImGui.Checkbox(tostring(Label or ""), Current)
            if Changed then
                StateTable[Key] = NewValue
                if type(OnChange) == "function" then 
                    SafeCall(OnChange, "Gui:ToggleKey:" .. tostring(Label), NewValue)
                end
            end

            Gui.Tooltip(TooltipText)
            return Changed, NewValue
        end

        function Gui.CheatToggle(OptionName, TooltipText, OnChange)
            if not Cheats or type(OptionName) ~= "string" then return false, false end

            local Changed, NewValue = ImGui.Checkbox(OptionName, Cheats[OptionName] == true)
            if Changed then
                Cheats[OptionName] = NewValue
                if type(OnChange) == "function" then 
                    SafeCall(OnChange, "Gui:CheatToggle:" .. OptionName, NewValue)
                end
            end

            Gui.Tooltip(TooltipText)
            return Changed, NewValue
        end

        function Gui.CheatRadioGroup(OptionList, SelectedName, TooltipText)
            if not Cheats or type(OptionList) ~= "table" then return false, SelectedName end

            local ChangedAny = false

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

            return ChangedAny, SelectedName
        end


    --> Close

    --> Inputs

        function Gui.InputText(Label, StateTable, Key, MaxLen, Flags, TooltipText)
            return Gui.InputTextKey(Label, StateTable, Key, MaxLen or 256, nil, Flags, TooltipText)
        end

        function Gui.InputInt(Label, StateTable, Key, Step, StepFast, Flags, TooltipText)
            local Changed, Val = ImGui.InputInt(Label, tonumber(StateTable[Key] or 0), Step or 1, StepFast or 10, Flags or 0)
            if Changed then StateTable[Key] = Val end
            Gui.Tooltip(TooltipText)
            return Changed, Val
        end

        function Gui.InputFloat(Label, StateTable, Key, Step, StepFast, Format, Flags, TooltipText)
            local Changed, Val = ImGui.InputFloat(Label, tonumber(StateTable[Key] or 0), Step or 0.1, StepFast or 1.0, Format or "%.3f", Flags or 0)
            if Changed then StateTable[Key] = Val end
            Gui.Tooltip(TooltipText)
            return Changed, Val
        end

        function Gui.SliderInt(Label, StateTable, Key, Min, Max, Format, Flags, TooltipText)
            local Changed, Val = ImGui.SliderInt(Label, tonumber(StateTable[Key] or 0), Min or 0, Max or 100, Format, Flags or 0)
            if Changed then StateTable[Key] = Val end
            Gui.Tooltip(TooltipText)
            return Changed, Val
        end

        function Gui.SliderFloat(Label, StateTable, Key, Min, Max, Format, Flags, TooltipText)
            local Changed, Val = ImGui.SliderFloat(Label, tonumber(StateTable[Key] or 0), Min or 0, Max or 1, Format or "%.3f", Flags or 0)
            if Changed then StateTable[Key] = Val end
            Gui.Tooltip(TooltipText)
            return Changed, Val
        end

        function Gui.ClampIntInput(Label, StateTable, Key, Min, Max, Step, StepFast, TooltipText)
            if type(StateTable) ~= "table" then return false, 0 end
            local Current = tonumber(StateTable[Key] or 0) or 0

            local Changed, NewValue = ImGui.InputInt(Label, Current, Step or 1, StepFast or 5)
            if ImGui.IsItemActive() and Max and NewValue > Max then
                ImGui.BeginTooltip()
                ImGui.TextColored(ImVec4(1.0, 0.3, 0.3, 1.0), Icon("Ban") .. " Maximum value is " .. tostring(Max) .. "!")
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
        end

    --> Close

    --> Select / Combo

        function Gui.Combo(Label, StateTable, Key, Items, TooltipText)
            local Current = tostring(StateTable[Key] or "")
            local Preview = Current ~= "" and Current or (Items and Items[1]) or ""
            local Changed = false

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
            return Changed, StateTable[Key]
        end

        function Gui.ComboIndex(Label, StateTable, Key, Items, TooltipText)
            local Idx = tonumber(StateTable[Key] or 1)
            if Idx < 1 then Idx = 1 end
            local Preview = tostring((Items or {})[Idx] or "")

            local Changed = false
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
            return Changed, StateTable[Key]
        end

        function Gui.Selectable(Label, Selected, OnClick, TooltipText, Location)
            if ImGui.Selectable(Label, Selected == true) then
                SafeCall(OnClick, Location or "Gui:Selectable:" .. tostring(Label))
                Gui.Tooltip(TooltipText)
                return true
            end
            Gui.Tooltip(TooltipText)
            return false
        end

    --> Close

    --> Colors

        function Gui.ColorEdit4(Label, StateTable, Key, Flags, TooltipText)
            local V = StateTable[Key]
            if type(V) ~= "table" then V = {1, 1, 1, 1} end

            local Changed, R, G, B, A = ImGui.ColorEdit4(Label, V[1], V[2], V[3], V[4], Flags or 0)
            if Changed then
                StateTable[Key] = {R, G, B, A}
            end

            Gui.Tooltip(TooltipText)
            return Changed, StateTable[Key]
        end

        function Gui.ColorButton(Label, Color, Size, TooltipText)
            ImGui.ColorButton(Label, Color or ImVec4(1, 1, 1, 1), 0, Size or ImVec2(20, 20))
            Gui.Tooltip(TooltipText)
        end

    --> Close

    --> Tabs / Trees / Tables

        function Gui.TabBar(Id, Tabs)
            if not ImGui.BeginTabBar(Id or "##TabBar") then return false end

            for _, T in ipairs(Tabs or {}) do
                local Label = T.Label or "Tab"
                local Flags = T.Flags or 0
                if ImGui.BeginTabItem(Label, nil, Flags) then
                    SafeCall(T.Draw, "Gui:TabBar:Tab_" .. tostring(Label), T)
                    ImGui.EndTabItem()
                end
            end

            ImGui.EndTabBar()
            return true
        end

        function Gui.TreeNode(Label, BodyFn, Flags)
            local Open = ImGui.TreeNodeEx(Label, Flags or 0)
            if Open then
                SafeCall(BodyFn, "Gui:TreeNode:" .. tostring(Label))
                ImGui.TreePop()
            end
            return Open
        end

        function Gui.Table(Id, ColumnCount, Flags, OuterSize, InnerWidth, HeaderFn, RowFn)
            if ImGui.BeginTable(Id, ColumnCount, Flags or 0, OuterSize or ImVec2(0, 0), InnerWidth or 0) then
                if HeaderFn then SafeCall(HeaderFn, "Gui:Table:" .. tostring(Id) .. ":Header") end
                if RowFn then SafeCall(RowFn, "Gui:Table:" .. tostring(Id) .. ":Row") end
                ImGui.EndTable()
                return true
            end
            return false
        end

        function Gui.TableHeaders(Headers)
            for _, H in ipairs(Headers or {}) do
                ImGui.TableSetupColumn(tostring(H))
            end
            ImGui.TableHeadersRow()
        end

    --> Close

    --> Popups / Modals

        function Gui.Popup(Id, BodyFn)
            if ImGui.BeginPopup(Id) then
                SafeCall(BodyFn, "Gui:Popup:" .. tostring(Id))
                ImGui.EndPopup()
                return true
            end
            return false
        end

        function Gui.OpenPopup(Id)
            ImGui.OpenPopup(Id)
        end

        function Gui.Modal(Id, BodyFn, Flags)
            local Open = true
            if ImGui.BeginPopupModal(Id, Open, Flags or 0) then
                SafeCall(BodyFn, "Gui:Modal:" .. tostring(Id))
                ImGui.EndPopup()
                return true
            end
            return false
        end

    --> Close

    --> Toolbar

        function Gui.Toolbar(Items, DefaultH)
            local H = DefaultH or 23
            for i, It in ipairs(Items or {}) do
                if i > 1 then Gui.SameLine() end

                local T = It.Type or "Button"
                if T == "Button" then
                    local W = It.W or 80
                    Gui.Button(It.Label or "Button", ImVec2(W, It.H or H), It.OnClick, It.Tip, "Gui:Toolbar:Button_" .. tostring(i))
                elseif T == "SmallButton" then
                    Gui.SmallButton(It.Label or "Button", It.OnClick, It.Tip, "Gui:Toolbar:SmallButton_" .. tostring(i))
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
        end
    
    --> Close

--> Close
