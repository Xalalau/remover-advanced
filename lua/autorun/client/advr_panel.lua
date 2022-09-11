--[[
		Created by: M4n0Cr4zy
		Colaborator: Xalalau Xubilozo 
		Special thanks to: Nodge 
]]

local ADVRFrame
local foundEntitiesQuant

local serverEntsList = {}
local highlighted = {}
local constraineds = {}
local entsIds = {
    cl = {},
    sv = {}
}

local highlightColor = Color(4, 0, 255, 255)
local deleteColor = Color(220, 0, 0, 255)
local foundEntitiesQuantColor = Color(255, 163, 169, 255)
local missingModelColor = Color(255, 163, 169, 255)

local leftClickPos


-- Remover highlight
net.Receive("m4n0cr4zy.Remove_Highlight_Cl", function()
    local entID = net.ReadUInt(32)

    highlighted[entID] = nil
end)


-- Atualizar posição de entidade server only (caso necessário)
net.Receive("m4n0cr4zy.Highlight_Update_Sv_Only_Ent_Pos", function()
    local entID = net.ReadUInt(32)
    local pos = net.ReadVector()

    entsIds.sv[entID].pos = pos
end)


-- Checar se a entidade é exclusiva do servidor
local function IsEntServerOnly(entID)
    return entsIds.sv[entID] and not entsIds.cl[entID]
end


-- Atualizar contador de entidades
local function UpdateCounter()
    foundEntitiesQuant:SetText(table.Count(EntsListView:GetLines()))
end

-- Remover uma entidade de uma das tabelas do entsIds. Infelizmente essa função é meio terrível
local function RemoveEntFromLists(entID)
    entsIds.cl[entID] = nil
    entsIds.sv[entID] = nil

    constraineds[entID] = nil

    for k, entInfo in ipairs(ADVRFrame.EntsListView.entsListCl) do
        if entInfo.index == entID then
            table.remove(ADVRFrame.EntsListView.entsListCl, k)
            break
        end
    end

    for k, entInfo in ipairs(ADVRFrame.EntsListView.entsListSv) do
        if entInfo.index == entID then
            table.remove(ADVRFrame.EntsListView.entsListSv, k)
            break
        end
    end
end


-- Remover highlight de todas as entidades
function ADVR_CleanupHighlights()
    for index, entInfo in pairs(highlighted) do
        if IsEntServerOnly(index) then
            net.Start("m4n0cr4zy.Remove_Highlight_Sv_Only_Ent")
                net.WriteUInt(index, 32)
                net.WriteBool(false)
            net.SendToServer()
        end
    end

    highlighted = {}
end


-- Renderizar highlight de entidades
hook.Add("HUDPaint", "ADVR_Highlight", function()
    local badIndexes = {}

    if next(highlighted) then
        for index, entInfo in pairs(highlighted) do
            if not entsIds.sv[entInfo.index] and not entsIds.sv[entInfo.index] then
                table.insert(badIndexes, index)
                continue
            end

            local basePos

            if IsEntServerOnly(index) then
                basePos = entInfo.pos
            else
                local ent = ents.GetByIndex(index)

                if not IsValid(ent) then
                    table.insert(badIndexes, index)
                    continue
                else
                    basePos = ent:GetPos()
                end
            end

            local distance = LocalPlayer():GetPos():Distance(basePos)
            local maxDistance = 700

            local up = Vector(0, 0, 25 * distance/maxDistance)

            local pos = basePos + Vector(0, 0, 7)
            local drawpos1 = basePos + up
            local drawpos2 = basePos
            drawposscreen1 = drawpos1:ToScreen()
            drawposscreen2 = drawpos2:ToScreen()

            draw.DrawText(entInfo.index, "Trebuchet24", drawposscreen1.x, drawposscreen1.y, color_white, TEXT_ALIGN_CENTER)
            draw.DrawText(entInfo.class, "Trebuchet24", drawposscreen2.x, drawposscreen2.y, color_white, TEXT_ALIGN_CENTER)

            if entInfo.name ~= "" then
                local drawpos3 = basePos - up
                drawposscreen3 = drawpos3:ToScreen()

                draw.DrawText(entInfo.name, "Trebuchet24", drawposscreen3.x, drawposscreen3.y, color_white, TEXT_ALIGN_CENTER)
            end
        end
    end

    if next(badIndexes) then
        for k, badIndex in ipairs(badIndexes) do
            highlighted[badIndex] = nil
        end
    end
end)
hook.Add("PreCleanupMap", "ADVR_Highlight_Cleanup", function()
    highlighted ={}
end)


-- Função para remover entidades
local function RemoveEnt(lines, EntsListView, IsConstrained)
    local selectedScope = EntsListView.scopeSelector:GetSelected()

    local netName = IsConstrained and "m4n0cr4zy.Remove_With_Constraineds" or "m4n0cr4zy.Remove"

    for k, curLine in ipairs(lines) do
        local curIndex = curLine:GetID()

        if entsIds.sv[curLine.entInfo.index] then -- Checar se não é um entidade do server.
            net.Start(netName)
                net.WriteUInt(curLine.entInfo.index, 32)
            net.SendToServer()
        else
            -- Às vezes uma entidade do server só é registrada no cliente e ela dá erro na hora de deletar
            -- Não sei como resolver isso, nem o pcall contém a mensagem de erro
            local ent = ents.GetByIndex(curLine.entInfo.index)

            local succ, err = pcall(function()
                if IsValid(ent) then
                    ent:Remove()
                end
            end)

            if succ then
                return
            else
                net.Start(netName)
                    net.WriteUInt(curLine.entInfo.index, 32)
                net.SendToServer()
            end
        end

        -- Remoção de entidade normal da listagem
        if not (IsConstrained and constraineds[curLine.entInfo.index]) then
            RemoveEntFromLists(curLine.entInfo.index)
            EntsListView:RemoveLine(curIndex)
        -- Remoção de entidade normal e seus constraints da listagem
        else
            local toRemove = {}

            for k, cEntIndex in ipairs(constraineds[curLine.entInfo.index]) do
                local cEntInfo = entsIds[selectedScope == "Server" and "sv" or "cl"][cEntIndex]

                if cEntInfo then
                    table.insert(toRemove, cEntInfo)
                end
            end

            for k, cEntInfo in ipairs(toRemove) do
                if cEntInfo.line and cEntInfo.line:IsValid() then
                    EntsListView:RemoveLine(cEntInfo.line:GetID())
                end

                RemoveEntFromLists(cEntInfo.index)
            end
        end
    end

    foundEntitiesQuant:SetText(table.Count(EntsListView:GetLines()))
end


-- Context menu das linhas
local function AddContextMenu(EntsListView, line)
    local lines = EntsListView:GetSelected()
    local entsList

    local contextMenu = DermaMenu()

    local contextRemoveOption = contextMenu:AddOption("Remove", function()
        RemoveEnt(lines, EntsListView, false)
    end)
    contextRemoveOption:SetColor(deleteColor)
    contextRemoveOption:SetIcon("icon16/delete.png")

    if #lines == 1 and constraineds[line.entInfo.index] then
        local contextRemoveWCOption = contextMenu:AddOption("Remove with constraineds", function()
            RemoveEnt(lines, EntsListView, true)
        end)
        contextRemoveWCOption:SetColor(deleteColor)
        contextRemoveWCOption:SetIcon("icon16/exclamation.png")
    end

    contextMenu:AddSpacer() 

    -- O index 0 é atribuido a várias entidades e aparece ao habilitar a listagem de
    -- entidades sem modelo, então não tem como dar highlight nessa situação
    local isIndex0Only = true 
    for k, curLine in ipairs(lines) do
        if curLine.entInfo.index ~= 0 then
            isIndex0Only = false
            break
        end
    end

    if not isIndex0Only then
        local contextHighlightOption = contextMenu:AddOption("Highlight", function()
            for k, curLine in ipairs(lines) do
                if curLine.entInfo.index == 0 then continue end

                if not highlighted[curLine.entInfo.index] then
                    highlighted[curLine.entInfo.index] = curLine.entInfo

                    for k, label in ipairs(curLine:GetChildren()) do
                        label:SetColor(highlightColor)
                    end

                    if IsEntServerOnly(curLine.entInfo.index) then
                        net.Start("m4n0cr4zy.Highlight_Sv_Only_Ent")
                            net.WriteUInt(curLine.entInfo.index, 32)
                            net.WriteBool(true)
                        net.SendToServer()
                    end
                else
                    highlighted[curLine.entInfo.index] = nil

                    for k, label in ipairs(curLine:GetChildren()) do
                        label:SetColor(Color(0, 0, 0, 255))
                    end

                    if IsEntServerOnly(curLine.entInfo.index) then
                        net.Start("m4n0cr4zy.Highlight_Sv_Only_Ent")
                            net.WriteUInt(curLine.entInfo.index, 32)
                            net.WriteBool(false)
                        net.SendToServer()
                    end
                end
            end
        end)
        contextHighlightOption:SetColor(highlightColor)
        contextHighlightOption:SetIcon("icon16/wand.png")
    end

    if #lines == 1 then
        contextMenu:AddOption("Look at", function()
            net.Start("m4n0cr4zy.Look")
                net.WriteVector(line.entInfo.pos)
            net.SendToServer()
        end):SetIcon("icon16/eye.png")

        contextMenu:AddOption("Teleport to", function()
            net.Start("m4n0cr4zy.Teleport")
                net.WriteVector(line.entInfo.pos)
            net.SendToServer()
        end):SetIcon("icon16/arrow_down.png")

        contextMenu:AddSpacer() 

        contextMenu:AddOption("Ignore class", function()
            if line.entInfo.class ~= "" then
                net.Start("m4n0cr4zy.Change_Blacklist")
                    net.WriteString(line.entInfo.class)
                    net.WriteBool(true)
                net.SendToServer()
            end
        end):SetIcon("icon16/tag_blue_delete.png")

        local subMenuCopy, parentMenuOption = contextMenu:AddSubMenu("Copy")
        parentMenuOption:SetIcon("icon16/page_white_copy.png")

        subMenuCopy:AddOption("Index", function()
            SetClipboardText(line.entInfo.index)
        end):SetIcon("icon16/key.png")

        subMenuCopy:AddOption("Class", function()
            SetClipboardText(line.entInfo.class)
        end):SetIcon("icon16/tag_blue.png")

        subMenuCopy:AddOption("Model", function()
            SetClipboardText(line.entInfo.model)
        end):SetIcon("icon16/car.png")

        subMenuCopy:AddSpacer() 

        if line.entInfo.name ~= "" then
            subMenuCopy:AddOption("Name", function()
                SetClipboardText(tostring(line.entInfo.name))
            end):SetIcon("icon16/text_smallcaps.png")
        end

        subMenuCopy:AddOption("Position", function()
            SetClipboardText(tostring(line.entInfo.pos))
        end):SetIcon("icon16/anchor.png")

        subMenuCopy:AddOption("Angles", function()
            SetClipboardText(tostring(line.entInfo.angles))
        end):SetIcon("icon16/shape_rotate_clockwise.png")

        subMenuCopy:AddOption("Normal", function()
            SetClipboardText(tostring(line.entInfo.normal))
        end):SetIcon("icon16/arrow_out.png")
    end

    contextMenu:Open()
end


-- Criar lista dentro do frame
local function BuildList(EntsListView, entsListCl, entsListSv)
    local selectedScope = EntsListView.scopeSelector:GetSelected()
    local entsList

    if selectedScope == "Server" then
        entsList = entsListSv
    else
        entsList = entsListCl
    end

    EntsListView.entsList = entsList

    for index, line in pairs(EntsListView:GetLines()) do
        EntsListView:RemoveLine(index)
    end

    local total = 0
    for k, entInfo in ipairs(entsList) do
        if entInfo.class ~= "" and not ADVRBlacklist[entInfo.class] then
            local modelPath = entInfo.model

            if entInfo.isMissing then
                modelPath = "[ERROR] " .. modelPath
            end

            local newLine = EntsListView:AddLine(entInfo.index, entInfo.class, modelPath)
            newLine.entInfo = entInfo
            entInfo.line = newLine

            if entInfo.isMissing then
                for k, label in ipairs(newLine:GetChildren()) do
                    --label:SetPaintBackgroundEnabled(true)
                    label:SetTextColor( Color( 255, 0, 0) )
                end
            end

            if highlighted[entInfo.index] then
                for k, label in ipairs(newLine:GetChildren()) do
                    label:SetColor(highlightColor)
                end
            end

            total = total + 1
        end
    end

    foundEntitiesQuant:SetText(total)

    EntsListView.OnRowRightClick = function(self, index, line)
        AddContextMenu(EntsListView, line)
    end

    EntsListView:SortByColumn(1, false)
end


-- Procurar por models
local function SearchForModels(entsSearch, EntsListView, entsListCl, entsListSv)
    local searchText = entsSearch:GetValue()
    local found = {
        cl = {},
        sv = {}
    }

    for k, entInfo in ipairs(entsListCl) do
        if string.find(entInfo.model, searchText) then
            table.insert(found.cl, entInfo)
        end
    end

    for k, entInfo in ipairs(entsListSv) do
        if string.find(entInfo.model, searchText) then
            table.insert(found.sv, entInfo)
        end
    end

    BuildList(EntsListView, found.cl, found.sv)
end


-- Criar frame
local function CreatePanel(entsListCl, entsListSv, width, height, x, y)
    if not ADVRFrame then
        ADVRFrame = vgui.Create("DFrame")
        ADVRFrame:SetDeleteOnClose(false)
        ADVRFrame:MakePopup()
        ADVRFrame:SetIcon("icon16/bin.png")
        ADVRFrame:SetTitle("Found Entities List:")
        ADVRFrame.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, ColorAlpha(color_black, 200))
        end

        foundEntitiesQuant = ADVRFrame:Add("DLabel")
        foundEntitiesQuant:SetPos(120, 2)
        foundEntitiesQuant:SetText("0")
        foundEntitiesQuant:SetColor(foundEntitiesQuantColor)

        local EntsListView = ADVRFrame:Add("DListView")
        ADVRFrame.EntsListView = EntsListView
        EntsListView:Dock(FILL)
        EntsListView:AddColumn("Index"):SetMaxWidth(45)
        EntsListView:AddColumn("Class"):SetMaxWidth(170)
        EntsListView:AddColumn("Model")

        local entsSearch = ADVRFrame:Add("DTextEntry")
        ADVRFrame.entsSearch = entsSearch
        entsSearch:Dock(TOP)
        entsSearch:SetPlaceholderText("Search model (Press Enter)")
        entsSearch.OnEnter = function(self)
            SearchForModels(self, EntsListView, EntsListView.entsListCl, EntsListView.entsListSv)
        end

        local scopeSelector = ADVRFrame:Add("DComboBox")
        local scopeSelectorWidth = 100
        EntsListView.scopeSelector = scopeSelector
        scopeSelector:SetPos(width/2 - scopeSelectorWidth/2, 5)
        scopeSelector:SetSize(scopeSelectorWidth, 20)
        scopeSelector:AddChoice("Server", nil, false, "icon16/application_osx_terminal.png")
        scopeSelector:AddChoice("Client", nil, false, "icon16/computer.png")
        scopeSelector:ChooseOption("Server", 1)
        scopeSelector.OnSelect = function(self, index, value)
            local searchText = entsSearch:GetValue()

            if searchText and searchText ~= "" then
                SearchForModels(entsSearch, EntsListView, EntsListView.entsListCl, EntsListView.entsListSv)
            else
                BuildList(EntsListView, EntsListView.entsListCl, EntsListView.entsListSv)
            end
        end
    end

    if ADVRFrame.lastWidth ~= height then
        ADVRFrame.lastWidth = height
        ADVRFrame:SetSize(width, height)
        ADVRFrame:Center()
        if x and y then
            ADVRFrame:SetPos(x, y)
        end
    end

    ADVRFrame.EntsListView.entsListSv = entsListSv
    ADVRFrame.EntsListView.entsListCl = entsListCl

    ADVRFrame:Show()

    local searchText = ADVRFrame.entsSearch:GetValue()

    if searchText and searchText ~= "" then
        SearchForModels(ADVRFrame.entsSearch, ADVRFrame.EntsListView, entsListCl, entsListSv)
    else
        BuildList(ADVRFrame.EntsListView, entsListCl, entsListSv)
    end
end


-- Descubro quais entidades são constraineds
local function GetConstraineds(entsListSv)
    constraineds = {}

    for k, entInfo in ipairs(entsListSv) do
        for j, entIndex in ipairs(entInfo.constraineds) do
            if not constraineds[entIndex] then
                constraineds[entIndex] = entInfo.constraineds
            end
        end
    end
end


-- Fazer uma lista com ids de entidades pra eu poder validar ou checar elas em outras funções
local function GetServerEntsIds(entsListCl, entsListSv)
    entsIds.cl = {}
    entsIds.sv = {}

    for k, entInfo in ipairs(entsListCl) do
        entsIds.cl[entInfo.index] = entInfo
    end

    for k, entInfo in ipairs(entsListSv) do
        entsIds.sv[entInfo.index] = entInfo
    end
end


-- Clique direito no tool
local function RightClick(entsListSv)
    local entsListCl = ADVR_GetAllEnts()

    local width = ScrW() * .5
    local height = ScrH() * .7

    GetServerEntsIds(entsListCl, entsListSv)
    GetConstraineds(entsListSv)

    CreatePanel(entsListCl, entsListSv, width, height)
end


-- Clique esquerdo no tool. Joga a info de um lado pro outro até ter tudo que precisa
net.Receive("m4n0cr4zy.Left_Click_1", function()
    if GetConVar("advr_enable_area_search"):GetBool() == false then return end

    local radius = GetConVar("advr_sphere_radius"):GetInt()
    local tr = LocalPlayer():GetEyeTrace()

    net.Start("m4n0cr4zy.Left_Click_2")
    net.WriteInt(radius, 13)
    net.WriteVector(tr.HitPos)
    net.SendToServer()

    leftClickPos = tr.HitPos
end)

local function LeftClick(entsListSv)
	local radius = GetConVar("advr_sphere_radius"):GetInt()

	local entsListCl = ADVR_GetAllEnts(leftClickPos, radius)

    leftClickPos = nil

    local width = ScrW() * .5
    local height = ScrH() * .4
    local x = ScrW() * .25
    local y = ScrH() * .55

    GetServerEntsIds(entsListCl, entsListSv)
    GetConstraineds(entsListSv)

    CreatePanel(entsListCl, entsListSv, width, height, x, y)
end


-- Clique direito no tool
net.Receive("m4n0cr4zy.Receive_Table_Cl", function()
    local clickType = net.ReadString()
    local currentChuncksID = net.ReadString()
    local len = net.ReadUInt(16)
    local chunk = net.ReadData(len)
    local lastPart = net.ReadBool()
    local pos = net.ReadVector()

    if not serverEntsList[currentChuncksID] then
        serverEntsList = {}
        serverEntsList[currentChuncksID] = ""
    end

    serverEntsList[currentChuncksID] = serverEntsList[currentChuncksID] .. chunk

    if lastPart then
        local entsListSv = util.JSONToTable(util.Decompress(serverEntsList[currentChuncksID]))
        
        if clickType == "RightClick" then
            RightClick(entsListSv)
        elseif clickType == "LeftClick" then
            LeftClick(entsListSv)
        end
	end
end)


-- Refazer listagem com as tabelas e configs existentes
function ADVR_RefreshMenu()
    if ADVRFrame and ADVRFrame:IsValid() and ADVRFrame.EntsListView and ADVRFrame.EntsListView:IsValid() then
        BuildList(ADVRFrame.EntsListView, ADVRFrame.EntsListView.entsListCl, ADVRFrame.EntsListView.entsListSv)
    end
end
