local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService		    = game:GetService('RunService')

local ProfileService    = require(script.ProfileService)
local Net 				      = require(ReplicatedStorage.Modules.Network)

local VERSION = RunService:IsStudio() and '_STUDIO' or '_V1'
VERSION = 1

local PlayerDefaults = {
	Cash        = 250,
	Steals      = 0,
	Rebirths    = 0,
	
	BaseData    = {
		BaseId      = 0,
		Slots       = {},      -- [slotIdx] = { BlockId, MutationId, Accumulated, lastClaim }
		LeftTime    = os.time()
	},
	UnlockedBlocks = {
		Normal = {}
	},
	Version = VERSION
}


local DataStoreHandler     = {}
DataStoreHandler.__index   = DataStoreHandler
DataStoreHandler._stores   = {}
DataStoreHandler._profiles = {}

local playerProfileName = 'PlayerProfile'..VERSION

function DataStoreHandler:Init()
	self._stores[playerProfileName] = ProfileService.GetProfileStore(
		playerProfileName, PlayerDefaults
	)

	Players.PlayerAdded:Connect(function(plr)
		self:_onPlayerAdded(plr)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		self:_onPlayerRemoving(plr)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(plr)
	end
end

function DataStoreHandler:_onPlayerAdded(player)
	local key     = tostring(player.UserId)
	local store   = assert(self._stores[playerProfileName], "No store configured")
	
	--store:WipeProfileAsync(key)
	if RunService:IsStudio() then
		--store:WipeProfileAsync(key)
	end
	
	local profile = store:LoadProfileAsync(key)

	if profile ~= nil then
		
		if profile.Data.Version ~= VERSION then
			print('Wiping data from '..player.Name..' because profile version is outdated')
			store:WipeProfileAsync(key)
			self:_onPlayerAdded(player)
			
			return
		end
		
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			self._profiles[key] = nil
			
			player:Kick("Your session expired. Please rejoin.")
		end)
		
		if player:IsDescendantOf(Players) == true then
			self._profiles[key] = profile
			
			local stats = Instance.new("Folder", player)
			stats.Name = "leaderstats"
			for _, name in ipairs({ "Cash", "Steals", "Rebirths" }) do
				local val = Instance.new("NumberValue", stats)
				val.Name  = name
				val.Value = profile.Data[name] or 0
			end
			
			profile.Data.BaseData.LeftTime = os.time()
			
			if profile.MetaData.SessionLoadCount == 1 then
				Net.getRemote('PlayerFirstJoin'):FireClient(player)
			end
			
		else
			profile:Release()
		end
	else
		player:Kick('Could not load your data. Please retry')
	end
end

function DataStoreHandler:_onPlayerRemoving(player)
	local key     = tostring(player.UserId)
	local profile = self._profiles[key]

	if profile ~= nil then
		
		profile.Data.BaseData.LeftTime = os.time()

		profile:Release()
		self._profiles[key] = nil
		
		--print('[DATASTORE]: '..player.Name..' profile was released, Profile:',profile)
	else
		warn('[DATASTORE] '..player.Name..' did not have a profile')
	end
end

function DataStoreHandler:GetProfile(player)
	return self._profiles[tostring(player.UserId)]
end

function DataStoreHandler:AddCash(player, amount)
	local profile = self:GetProfile(player)
	if profile then
		profile.Data.Cash = (profile.Data.Cash or 0) + amount
		player.leaderstats.Cash.Value = profile.Data.Cash
		Net.getRemote('CashChanged'):FireClient(player, profile.Data.Cash)
		return profile.Data.Cash
	end
end

function DataStoreHandler:CreateOrUpdateSlot(player, slotIdx, blockId, mutationId)
	local profile   = self:GetProfile(player)
	local slots     = profile and profile.Data.BaseData.Slots
	if not slots then return end
	
	slotIdx = tostring(slotIdx)
	
	slots[slotIdx] = slots[slotIdx] or {}
	slots[slotIdx].BlockId      = blockId
	slots[slotIdx].MutationId   = mutationId or 0
	slots[slotIdx].Accumulated  = slots[slotIdx].Accumulated or 0
	slots[slotIdx].lastClaim    = slots[slotIdx].lastClaim or os.time()
	
	--print('[DATASTORE]: Saved slot data, profile:',profile)
end

function DataStoreHandler:GetSlot(player, slotIdx)
	local profile = self:GetProfile(player)
	local slots   = profile and profile.Data.BaseData.Slots
	if not slots then return end
	
	slotIdx = tostring(slotIdx)
	return slots[slotIdx]
end

function DataStoreHandler:DeleteSlot(player, slotIdx)
	slotIdx = tostring(slotIdx)
	local profile = DataStoreHandler:GetProfile(player)
	if profile and profile.Data.BaseData.Slots[slotIdx] then
		profile.Data.BaseData.Slots[slotIdx] = nil
	else
		warn('profile.Data.Slots[slotidx] does not exist', profile)
	end
end

function DataStoreHandler:CalculateOfflineIncome(player, slotIdx)
	local profile  = self:GetProfile(player)
	local slotData = profile and profile.Data.BaseData.Slots[tostring(slotIdx)]
	if not slotData then return 0 end

	local now      = os.time()
	local elapsed  = now - (profile.Data.BaseData.LeftTime or now)
	local BlockData = require(ServerStorage.Modules.BlockSpawner):GetData(slotData.BlockId)
	return (BlockData.IncomePerSecond or 0) * (elapsed * 10)
end

function DataStoreHandler:UpdateLeaveTime(player)
	local profile = self:GetProfile(player)
	if profile then
		profile.Data.BaseData.LeftTime = os.time()
	end
end

return DataStoreHandler
