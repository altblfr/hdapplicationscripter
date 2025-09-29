local Players = game:GetService('Players')
local ServerStorage = game:GetService('ServerStorage')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local RagdollHandler   = require(ServerStorage.Modules.RagdollHandler)
local DataStoreHandler = require(ServerStorage.Modules.DataStoreHandler)
local Signal 		   = require(ReplicatedStorage.Modules._Signal)
local rebirthsData 	   = require(ReplicatedStorage.Datas.RebirthsData)
local GearsData 	   = require(ReplicatedStorage.Datas.Gears)
local Net			   = require(ReplicatedStorage.Modules.Network)

Net.registerRemote({
	Name = 'PlayerDataLoaded'
})

local Player = {}
Player.Ragdolled   = Signal.new()
Player.Unragdolled = Signal.new()
Player.loadedClients = {}

local PlayerData = {}

local flags = {
	['Prompts'] = {},
}

function Player:addIndex(player: Player)	
	repeat
		task.wait()
	until player.Character
	
	RagdollHandler.setupPlayer(player)
	player:SetAttribute('Ragdolled', false)
	
	local flagsFolder = Instance.new('Folder')
	flagsFolder.Name = 'Flags'
	flagsFolder.Parent = player
	
	for flagType, flagsHolder in flags do
		local folder = Instance.new('Folder')
		folder.Name = flagType
		folder.Parent = flagsFolder
		
		for flagName, flagValue in flagsHolder do
			folder:SetAttribute(flagName, false)
		end
	end
	
	PlayerData[player] = {
		BaseData = {
			Base = nil,
			Id = nil,
		},
		Cash = 999999,
		Ragdolled = false,
		_lastRagdolledFinishTime = 0,
		Gears = {},
		Health = 200,
		_gearcleanup = nil
	}
	
	Net.waitForRemote('PlayerDataLoaded'):FireClient(player, PlayerData[player])
	
	print('[SESSION]: Tracking '..player.Name)
end

function Player:GetCash(player: Player)
	local playerBaseData = DataStoreHandler:GetProfile(player)
	
	if playerBaseData == nil then
		warn('[SESSION]: Player base data could not be fetched.')
		return
	end
	
	return playerBaseData.Data.Cash
end

function Player:Rebirth(player: Player)
	local profile = DataStoreHandler:GetProfile(player)
	
	profile.Data.Rebirths += 1
	player.leaderstats.Rebirths.Value = profile.Data.Rebirths
	
	profile.Data.BaseData.Slots = {}
	
	Player:SetCash(player, rebirthsData[profile.Data.Rebirths].StarterCash)
	
	ServerStorage.Bindables.OnPlayerRebirth:Fire(player)
end

function Player:CreateFlag(player: Player, type: string, name: string, value: boolean)
	if not PlayerData[player] then
		self:WaitForPlayer(player)
	end
	
	local flag = Instance.new('BoolValue')
	flag.Name = name
	flag.Value = value
	
	flag.Parent = player.Flags[type]
	return flag
end

function Player:RemoveFlag(player: Player, type: string, name: string)
	if not PlayerData[player] then
		self:WaitForPlayer(player)
	end
	
	player.Flags[type][name]:Destroy()
end

function Player:SetFlag(player: Player, type: string, name: string, value: boolean)
	if not PlayerData[player] then
		self:WaitForPlayer(player)
	end
	
	player.Flags[type][name].Value = value
end

function Player:ClientPingLoaded(player: Player)
	Player.loadedClients[player] = true
end

function Player:SetCash(player: Player, amount: number)
	local playerBaseData = DataStoreHandler:GetProfile(player)

	if playerBaseData == nil then
		warn('[SESSION]: Player base data could not be fetched.')
		return
	end

	playerBaseData.Data.Cash = amount
	player.leaderstats.Cash.Value = playerBaseData.Data.Cash

	Net.getRemote('CashChanged'):FireClient(player, playerBaseData.Data.Cash)

	return playerBaseData.Data.Cash
end

function Player:AddCash(player: Player, amount: number)
	local playerBaseData = DataStoreHandler:GetProfile(player)
	
	if playerBaseData == nil then
		warn('[SESSION]: Player base data could not be fetched.')
		return
	end
	
	playerBaseData.Data.Cash += amount
	player.leaderstats.Cash.Value = playerBaseData.Data.Cash
	
	Net.getRemote('CashChanged'):FireClient(player, playerBaseData.Data.Cash)
	
	return playerBaseData.Data.Cash
end

function Player:AddBlockToIndex(player: Player, blockId: number)
	local profile = DataStoreHandler:GetProfile(player)
	if not profile then
		player:Kick('Your profile with your data was not found, rejoin and try again.')
		return
	end
	
	if not table.find(profile.Data.UnlockedBlocks.Normal, blockId) then
		print('Unlocked a new block')
		table.insert(profile.Data.UnlockedBlocks.Normal, blockId)
		Net.getRemote('Block_AddedToIndex'):FireClient(player, blockId)
	end
end

function Player:GetLoadedPlayers()
	local players = {}
	for i, v in PlayerData do
		table.insert(players, i)
	end
	return players
end

function Player:WaitForPlayer(player: Player)
	local start = tick()
	local elapsed = 0
	repeat
		elapsed = tick() - start
		if elapsed > 120 then
			player:Kick('Your data could not be loaded. Rejoin and try again.')
			break
		end
		task.wait()
	until PlayerData[player] ~= nil 
		and DataStoreHandler:GetProfile(player) ~= nil
		and PlayerData[player].BaseData ~= nil 
		and Player.loadedClients[player] == true
	
	return PlayerData[player]
end

function Player:Impulse(player, vector: Vector3)
	local character = player.Character
	local bodyVelocity = Instance.new('BodyVelocity')
	bodyVelocity.MaxForce = Vector3.new(1000000, 1000000, 1000000)
	bodyVelocity.Velocity = vector
	bodyVelocity.Parent = character.HumanoidRootPart

	task.delay(.1, function()
		bodyVelocity:Destroy()
	end)
end

function Player:Ragdoll(player: Player, time: number, impulse: Vector3?)
	if player:GetAttribute('Ragdolled') == true then
		print('already ragdolling')
		return
	end
	
	if not player.Character then return end
	
	local now = tick()
	
	if now - PlayerData[player]._lastRagdolledFinishTime < 2 then -- 2 second grace period after ragdoll is finished
		print('Ragdoll grace period not over yet')
		return
	end
	

	
	task.spawn(function()
		player:SetAttribute('Ragdolled', true)
		Player.Ragdolled:Fire(player)
		
		task.wait(time)
		
		player:SetAttribute('Ragdolled', false)
		Player.Unragdolled:Fire(player)
		PlayerData[player]._lastRagdolledFinishTime = tick()
		
	end)
end

function Player:EquipGear(player: Player, name: string)
	local character = player.Character
	if not character then
		warn('Player:EquipGear : No character was found for '..player.Name)
		return
	end
	
	local gearData
	for i, data in GearsData do
		if data.Name == name then
			gearData = data
			break
		end
	end
	
	if not gearData then
		warn('Player:EquipGear : Invalid gear id, gearData was not found, gearname:',name)
		return
	end
	
	local gear = character:FindFirstChildOfClass('Tool')
	if not gear then
		warn('Player:EquipGear : No gear on character model')
		return
	end
	
	if gear.Name ~= gearData.Name then
		warn('Player:EquipGear : Character gear and gear data does not coincide')
		return
	end
	
	local playerData = Player:Get(player)
	
	if playerData._gearcleanup then
		print('Player:EquipGear : Cleaning previous gear behavior')
		playerData._gearcleanup()
	end
	
	local gearBehavior = require(ServerStorage.Gears.Behaviors:FindFirstChild(gearData.Name))
	local cleanup = gearBehavior(gear, gearData)
	
	playerData._gearcleanup = cleanup
end

function Player:removeIndex(player: Player)
	PlayerData[player] = nil
end

function Player:Get(player: Player)
	return PlayerData[player]
end

Players.PlayerAdded:Connect(function(player)
	Player:addIndex(player)
end)
Players.PlayerRemoving:Connect(function(player)
	Player:removeIndex(player)
end)

return Player
