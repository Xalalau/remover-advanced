--[[
		Created by: M4n0Cr4zy
		Colaborator: Xalalau Xubilozo 
		Special thanks to: Nodge 
]]

TOOL.Category   = "Construction"
TOOL.Name       = "Remover - Advanced"
TOOL.Command    = nil
TOOL.ConfigName = ""

if CLIENT then
	TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
		{ name = "reload" },
		{ name = "use" },
		{ name = "info" }
	}

    language.Add("tool.removeradvanced.name", "Remover - Advanced")
    language.Add("tool.removeradvanced.desc", "Selectively remove entities")
	language.Add("tool.removeradvanced.left", "Search entities within a spherical area")
	language.Add("tool.removeradvanced.right","List all entities")
	language.Add("tool.removeradvanced.reload", "Remove hit object ('single' mode) and all objects constraint to it ('constraint' mode)")
	language.Add("tool.removeradvanced.use", "Alternate between 'single' and 'constraint' hit objects removal modes")
	language.Add("tool.removeradvanced.0", "Right-click the listed entities to display the context menu")

	CreateClientConVar("advr_sphere_radius", "80", true, false)
	CreateClientConVar("advr_enable_area_search", "true", true, false)
	CreateClientConVar("advr_allow_no_model", "false", true, false)
	CreateClientConVar("advr_allow_weapons", "false", true, false)
else
	util.AddNetworkString("m4n0cr4zy.Receive_Table_Cl")
	util.AddNetworkString("m4n0cr4zy.Left_Click_1")
	util.AddNetworkString("m4n0cr4zy.Left_Click_2")
	util.AddNetworkString("m4n0cr4zy.Right_Click_1")
	util.AddNetworkString("m4n0cr4zy.Right_Click_2")
	util.AddNetworkString("m4n0cr4zy.Set_Blacklist")
	util.AddNetworkString("m4n0cr4zy.Reset_Blacklist")
	util.AddNetworkString("m4n0cr4zy.Tool_Swaped")
end


ADVRBlacklist = nil
local defaultBlacklist = {
	["player"] = true,
	["gmod_hands"] = true,
	["viewmodel"] = true,
	["worldspawn"] = true,
	["func_brush"] = true,
	["func_illusionary"] = true,
	["class C_BaseEntity"] = true,
	["class C_Sun"] = true,
	["predicted_viewmodel"] = true
}

local usingTool = false
local removalMode = 'single'

local checkBoxSphere
local blacklistMenu

local dataFolder = "advremover"
local blacklistFile = dataFolder .. "/blacklist.txt"

local lastSentChunksID

file.CreateDir(dataFolder)


-- Carregar blacklist
local function LoadBlacklist()
	ADVRBlacklist = file.Read(blacklistFile, "DATA")
	if ADVRBlacklist then
		ADVRBlacklist = util.JSONToTable(ADVRBlacklist)

		hook.Add("PlayerInitialSpawn", "ADVRFullLoadSetup", function(ply)
			hook.Add("SetupMove", ply, function(self, ply, _, cmd)
				if self == ply and not cmd:IsForced() then
					net.Start("m4n0cr4zy.Set_Blacklist")
					net.WriteTable(ADVRBlacklist)
					net.Send(ply)

					hook.Remove("SetupMove", self)
				end
			end)
		end)
	else
		ADVRBlacklist = table.Copy(defaultBlacklist)
	end
end


-- Modificar itens da blacklist e salvar alterações
if SERVER then
	function ADVR_BlacklistClass(class, isBlacklisted)
		ADVRBlacklist[class] = isBlacklisted

		net.Start("m4n0cr4zy.Set_Blacklist")
		net.WriteTable(ADVRBlacklist)
		net.Broadcast()

		file.Write(blacklistFile, util.TableToJSON(ADVRBlacklist, true))
	end
end

if CLIENT then
	net.Receive("m4n0cr4zy.Set_Blacklist", function()
	    ADVRBlacklist = net.ReadTable()

		if blacklistMenu then
			for index, foundLine in pairs(blacklistMenu:GetLines()) do
				blacklistMenu:RemoveLine(index)
			end

			for class, isBlacklisted in pairs(ADVRBlacklist) do
				if isBlacklisted then
					blacklistMenu:AddLine(class)
				end
			end

			blacklistMenu:SortByColumn(1, false)

			ADVR_RefreshMenu()
		end
	end)
end


-- Resetar a blacklist
local function ResetBlacklist()
	ADVRBlacklist = table.Copy(defaultBlacklist)

	net.Start("m4n0cr4zy.Reset_Blacklist")
	net.SendToServer()
end

if SERVER then
	net.Receive("m4n0cr4zy.Reset_Blacklist", function()
	    ADVRBlacklist = table.Copy(defaultBlacklist)

		file.Write(blacklistFile, util.TableToJSON(ADVRBlacklist, true))
	end)
end


-- Enviar tabela para o cliente
--   Portei essa função do meu gm_construct 13 beta :) - Xala
local function SendTable(sendTab, ply, clickType)
    if CLIENT then return end

	local currentChuncksID = tostring(sendTab)

	lastSentChunksID = currentChuncksID

	sendTab = util.Compress(util.TableToJSON(sendTab))
	local totalSize = string.len(sendTab)

	local chunkSize = 55000 -- 55KB
	local totalChunks = math.ceil(totalSize / chunkSize)

	for i = 1, totalChunks, 1 do
		local startByte = chunkSize * (i - 1) + 1
		local remaining = totalSize - (startByte - 1)
		local endByte = remaining < chunkSize and (startByte - 1) + remaining or chunkSize * i
		local chunk = string.sub(sendTab, startByte, endByte)

		timer.Simple(i * 0.05, function()
			if lastSentChunksID ~= currentChuncksID then return end

			local isLastChunk = i == totalChunks

			net.Start("m4n0cr4zy.Receive_Table_Cl")
			net.WriteString(clickType)
			net.WriteString(currentChuncksID)
			net.WriteUInt(#chunk, 16)
			net.WriteData(chunk, #chunk)
			net.WriteBool(isLastChunk)
			if ply then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end)
	end
end


-- Botão esquerdo: Busca localizada (esfera)
function TOOL:LeftClick(trace)
	local owner = self:GetOwner()

	if not owner:IsAdmin() then
		owner:PrintMessage(HUD_PRINTTALK, "Admin only tool!")
		return false
	end

	if SERVER then
        net.Start("m4n0cr4zy.Left_Click_1")
        net.Send(owner)
    end	

	return false
end

if SERVER then
	net.Receive("m4n0cr4zy.Left_Click_2", function(_, ply)
		local radius = net.ReadInt(13)
		local pos = net.ReadVector()
		local allow_weapons = net.ReadBool()
		local allow_no_model = net.ReadBool()

		local sendTab = ADVR_GetAllEnts(pos, radius, allow_weapons, allow_no_model)
		local clickType = "LeftClick"

		SendTable(sendTab, ply, clickType)
	end)
end


-- Enviar tabela de entidades do servidor para o cliente (em partes) e abrir menu com todas as entidades dos dois lados
function TOOL:RightClick(trace)
	local owner = self:GetOwner()

	if not owner:IsAdmin() then
		owner:PrintMessage(HUD_PRINTTALK, "Admin only tool!")
		return false
	end
	if SERVER then
        net.Start("m4n0cr4zy.Right_Click_1")
        net.Send(owner)
    end	

	return false
end

if SERVER then
	net.Receive("m4n0cr4zy.Right_Click_2", function(_, ply)
		local allow_weapons = net.ReadBool()
		local allow_no_model = net.ReadBool()

		local sendTab = ADVR_GetAllEnts(nil, nil, allow_weapons, allow_no_model)
		local clickType = "RightClick"
	
		SendTable(sendTab, ply, clickType)
	end)
end


-- Remover entidade e constraints
-- Diretamente do remover tool do GMod
function TOOL:Reload(trace)
	local owner = self:GetOwner()

	if not owner:IsAdmin() then
		owner:PrintMessage(HUD_PRINTTALK, "Admin only tool!")
		return false
	end

	local ent = trace.Entity

	if removalMode == 'single' then
		return ADVR_RemoveEnt(ent)
	elseif removalMode == 'constraint' then
		return ADVR_RemoveEntWithConstraineds(ent)
	end

	return false
end

if SERVER then
	hook.Add("KeyPress", "ADVRKeyPressUse", function(ply, key)
		if key == IN_USE and usingTool then
			if removalMode == 'single' then
				removalMode = 'constraint'
			else
				removalMode = 'single'
			end

			ply:PrintMessage(HUD_PRINTCENTER, "'" .. removalMode .. "' mode selected")
		end
	end)
end


-- Remover a bolinha
local function RemoveSphere()
	if SERVER then return end

	hook.Remove("PostDrawTranslucentRenderables", "ADVRSphereHook")
end


-- Desenha a bola na tela ao clicar com o esquerdo e se o Checked estiver marcado
local function SetSphere(ply, value)
	if SERVER then return end
	if not IsValid(ply) or not ply.GetActiveWeapon then return end

	local isSphereEnabled = GetConVar("advr_enable_area_search"):GetBool()

	if isSphereEnabled then	
		local radius = value or GetConVar("advr_sphere_radius"):GetInt()
		local longitude = 10
		local altitude = 10

		hook.Add("PostDrawTranslucentRenderables", "ADVRSphereHook", function(isDrawingDepth, isDrawSkybox, isDraw3DSkybox)
			if isDrawingDepth or isDrawSkybox or isDraw3DSkybox then return end

			local currentWeapon = ply:GetActiveWeapon()

			if not IsValid(currentWeapon) or
			   not currentWeapon.GetClass or
			   not currentWeapon.GetTable
			then
				RemoveSphere()
				return
			end

			if currentWeapon:GetClass() ~= 'gmod_tool' or
			   currentWeapon:GetTable()['current_mode'] ~= 'removeradvanced'
			then
				return
			end

			if not usingTool then
				RemoveSphere()
				return
			end

			local pos = LocalPlayer():GetEyeTrace().HitPos			

			render.SetColorMaterial()
			render.DrawSphere(pos, radius, longitude, altitude, Color(0, 255, 0, 40), true)
			render.DrawWireframeSphere(pos, radius, longitude, altitude, Color(0, 0, 0, 255), true)	
		end)
	end
end


-- Identificar uso da ferramenta - Xala
--     Nota: Deploy e Holster são predicted, então no singleplayer eles só rodam no serverside
--           Deploy é chamado ao pegar ferramenta (às vezes mais de uma vez)
--				Bug: se o jogador tiver a ferramenta pré selecionada ao iniciar o game, o deploy não
--                   é chamado ao selecioná-la diretamente pela menu de armas, apenas a partir da
--                   segunda seleção. Isso é contornado com uma ativação extra da esfera durante a
--                   construção do menu e pela verificação da arma do jogador.
--           Holster é chamado ao tirar a ferramenta (às vezes mais de uma vez)
local function ToolSwaped(ply, state)
    if not ply:IsAdmin() then return end

	usingTool = state

	if CLIENT then
		if usingTool then
			SetSphere(ply)
		else
			RemoveSphere()
		end
	else
		net.Start("m4n0cr4zy.Tool_Swaped")
		net.WriteBool(state)
		net.Send(ply)
	end
end
net.Receive("m4n0cr4zy.Tool_Swaped", function(len, ply)
	local state = net.ReadBool()
	ply = CLIENT and LocalPlayer() or ply

	ToolSwaped(ply, state)
end)
function TOOL:Deploy()
	if SERVER then
		ToolSwaped(self:GetOwner(), true)
	end
end
function TOOL:Holster()
	if SERVER then
		ToolSwaped(self:GetOwner(), false)
	end
end

function TOOL.BuildCPanel(CPanel)
	local menuMargin = 5
	local initializedMenu = false

    if not LocalPlayer():IsAdmin() then
		local adminWarning = vgui.Create("DLabel", CPanel)
		adminWarning:SetPos(10, 25 + menuMargin)
		adminWarning:SetWide(210)
		adminWarning:SetText("Admin only tool!")
		adminWarning:SetDark(true)
		return
	end

	-- Checkbox	de ativação da busca por área
	-- -----------------------------------------------------------------------------------------------------------------

	checkBoxSphere = vgui.Create("DCheckBoxLabel", CPanel)
	checkBoxSphere:SetPos(10, 25 + menuMargin)
	checkBoxSphere:SetText("Search by area (sphere)")
	checkBoxSphere:SetConVar("advr_enable_area_search")
	checkBoxSphere:SetDark(true)
	
	function checkBoxSphere:OnChange(val)
		if not initializedMenu then return end

		if val then
			SetSphere(LocalPlayer())
		else
			RemoveSphere()
		end
	end

	checkBoxSphere:SetValue(true)

	-- Tamanho da esfera de busca
	-- -----------------------------------------------------------------------------------------------------------------

	-- NumSlider - 'Barra' - tamanho da bolinha
	local sphereSize = vgui.Create("DNumSlider", CPanel)
	sphereSize:SetPos(10, checkBoxSphere:GetY() + checkBoxSphere:GetTall() + menuMargin)
	sphereSize:SetSize(50, 25)
	sphereSize:SetMinMax(5, 3000)
	sphereSize:SetDecimals(0)
	sphereSize:SetConVar("advr_sphere_radius")
	sphereSize:SetDark(true)
	sphereSize:SetWide(210)
	sphereSize.Label:SetVisible(false) 	

	local sphereSizeLabel = vgui.Create ("DLabel", sphereSize)
	sphereSizeLabel:Dock(LEFT)
	sphereSizeLabel:SetText(" Radius:")
	sphereSizeLabel:SetDark(true)
    sphereSizeLabel:SetWide(40)

	-- Ativar o checkbox da busca automaticamente ao mover o slider
	local onMouseFunc = sphereSize.Slider.OnMousePressed
	sphereSize.Slider.OnMousePressed = function(self, keyCode)
		checkBoxSphere:SetValue(true)
		onMouseFunc(sphereSize.Slider)
	end

	-- Se alterar a bara atualizar o tamanho da bola
	sphereSize.OnValueChanged = function(self, value)
		if not initializedMenu then return end
		SetSphere(LocalPlayer(), value)
	end

	-- Foçar o slider para o valor certo ao criar o menu
	timer.Simple(0.3, function()
		if sphereSize:IsValid() then
			sphereSize:SetValue(GetConVar("advr_sphere_radius"):GetInt())
		end
	end)

	-- Controle das classes blacklisted
	-- -----------------------------------------------------------------------------------------------------------------

    blacklistMenu = vgui.Create("DListView", CPanel)
	blacklistMenu:SetPos(10, sphereSize:GetY() + sphereSize:GetTall() + menuMargin)
	blacklistMenu:SetSize(200, 300)
    blacklistMenu:AddColumn("Ignored Classes")

    for class, isBlacklisted in SortedPairs(ADVRBlacklist) do
		if isBlacklisted then
	        blacklistMenu:AddLine(class)
		end
    end

    blacklistMenu:SortByColumn(1, false)

	local removeFromBlacklistButton = vgui.Create("DButton", CPanel)
	removeFromBlacklistButton:SetText("Remove from the list")
	removeFromBlacklistButton:SetPos(10, blacklistMenu:GetY() + blacklistMenu:GetTall() + menuMargin)
	removeFromBlacklistButton:SetSize(145, 25)
	removeFromBlacklistButton.DoClick = function()
        local lines = blacklistMenu:GetSelected()

		for k, curLine in ipairs(lines) do
			net.Start("m4n0cr4zy.Change_Blacklist")
				net.WriteString(curLine:GetColumnText(1))
				net.WriteBool(false)
			net.SendToServer()
		end
	end

	local resetBlacklistButton = vgui.Create("DButton", CPanel)
	resetBlacklistButton:SetText("Reset")
	resetBlacklistButton:SetPos(10 + removeFromBlacklistButton:GetWide() + menuMargin, blacklistMenu:GetY() + blacklistMenu:GetTall() + menuMargin)
	resetBlacklistButton:SetSize(50, 25)
	resetBlacklistButton.DoClick = function()
		ResetBlacklist()

		blacklistMenu:Clear()

		for class, isBlacklisted in SortedPairs(ADVRBlacklist) do
			if isBlacklisted then
				blacklistMenu:AddLine(class)
			end
		end
	end

	-- Checkbox	para mostrar entidades sem modelo definido
	-- -----------------------------------------------------------------------------------------------------------------

	local checkBoxWeapons = vgui.Create("DCheckBoxLabel", CPanel)
	checkBoxWeapons:SetPos(10, removeFromBlacklistButton:GetY() + removeFromBlacklistButton:GetTall() + menuMargin)
	checkBoxWeapons:SetText("List weapons")
	checkBoxWeapons:SetConVar("advr_allow_weapons")
	checkBoxWeapons:SetDark(true)

	-- Checkbox	para permitir armas
	-- -----------------------------------------------------------------------------------------------------------------

	local checkBoxNoModel = vgui.Create("DCheckBoxLabel", CPanel)
	checkBoxNoModel:SetPos(10, checkBoxWeapons:GetY() + checkBoxWeapons:GetTall() + menuMargin)
	checkBoxNoModel:SetText("List entities without models")
	checkBoxNoModel:SetConVar("advr_allow_no_model")
	checkBoxNoModel:SetDark(true)

	-- Limpar todos os highlights
	-- -----------------------------------------------------------------------------------------------------------------

	local removeFromBlacklistButton = vgui.Create("DButton", CPanel)
	removeFromBlacklistButton:SetText("Cleanup Highlights")
	removeFromBlacklistButton:SetPos(10, checkBoxNoModel:GetY() + checkBoxNoModel:GetTall() * 3 + menuMargin)
	removeFromBlacklistButton:SetSize(200, 25)
	removeFromBlacklistButton.DoClick = ADVR_CleanupHighlights

	-- Algumas gambiarras para controlar a renderização da esfera
	timer.Simple(1, function()	
		initializedMenu = true -- evita que ToolSwaped seja chamado pelos menus
	end)
	if not usingTool then
		ToolSwaped(LocalPlayer(), true) -- Garanto que começo com a esfera ligada
	end
end

LoadBlacklist()