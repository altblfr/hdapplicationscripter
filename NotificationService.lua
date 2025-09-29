local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService 		= game:GetService('TweenService')
local Debris 			= game:GetService('Debris')
local Players 			= game:GetService('Players')
local SoundService 		= game:GetService('SoundService')

local player 	= Players.LocalPlayer
local playerGui = player.PlayerGui

local notificationsGUI = playerGui:WaitForChild('Notifications')

local Types   = require(script.Types)
local Config  = require(script.Config)

local module = {}

function module:Init()
	
end

function module:Success(message: string)
	module:Notify({
		Type = 'Bottom',
		Message = message,
		Sound = ReplicatedStorage.Sounds.FX["electronicpingshort.wav"],
		Color = Color3.new(0.133333, 0.882353, 0.133333)
	})
end

function module:Achievment(header, message:string)
	module:Notify({
		Type = 'Left',
		Header = header,
		Message = message,
		Sound = ReplicatedStorage.Sounds.FX["victory.wav"],
	})
end

function module:Notify(notificationData: Types.Notification)
	local notificationAsset = script.NotificationsUI:FindFirstChild(notificationData.Type)
	assert(notificationAsset, 'Invalid notification type, Notification.Type: '..tostring(notificationData.Type))
	
	local notification = notificationAsset:Clone()
	
	if notificationData.Type == 'Top' then
		
		notificationData.Color = notificationData.Color or Color3.new(1,1,1)
		
		notification.Message.Text = notificationData.Message
		notification.Message.TextTransparency = Config.Notifications.Top.TransparencyStart
		notification.Message.TextStrokeTransparency = Config.Notifications.Top.TransparencyStart
		notificationData.Message.TextColor3 = notificationData.Color
		
		notification.Parent = notificationsGUI:WaitForChild('ServerNotifications')
		
		TweenService:Create(notification.Message, Config.Notifications.Top.TransparencyTweenInfo, 
			{TextTransparency = 0, TextStrokeTransparency = 0}):Play()
		
		task.delay(notificationData.Duration or 8, function()		
			local tween = TweenService:Create(notification.Message, Config.Notifications.Top.TransparencyTweenInfo, 
				{TextTransparency = 1, TextStrokeTransparency = 1})
			tween:Play()
			
			tween.Completed:Once(function()
				notification:Destroy()
			end)
		end)
		
	elseif notificationData.Type == 'Bottom' then
		
		notificationData.Color = notificationData.Color or Color3.new(1,1,1)
		
		local message: TextLabel = notification.Message
		
		message.Text = notificationData.Message or 'Insert text'
		message.TextTransparency = 0--Config.Notifications.Top.TransparencyStart
		message.TextStrokeTransparency = 0--Config.Notifications.Top.TransparencyStart
		message.TextColor3 = notificationData.Color

		notification.Parent = notificationsGUI:WaitForChild('AchievmentsList')

		--TweenService:Create(message, Config.Notifications.Top.TransparencyTweenInfo, 
			--{TextTransparency = 0, TextStrokeTransparency = 0}):Play()

		task.delay(notificationData.Duration or 5, function()		
			local tween = TweenService:Create(notification.Message, Config.Notifications.Bottom.TransparencyEndTweenInfo, 
				{TextTransparency = 1, TextStrokeTransparency = 1})
			tween:Play()

			tween.Completed:Once(function()
				notification:Destroy()
			end)
		end)
	elseif notificationData.Type == 'Left' then

		notification.Header.Text = notificationData.Header
		notification.Content.Text = notificationData.Message
		
		local flash = script.VFX.Flash:Clone()
		flash.ImageTransparency = 0
		flash.Parent = notification
		
		local tween = TweenService:Create(flash, Config.Notifications.Left.FlashTweenInfo, {ImageTransparency = 1})

		notification.Parent = notificationsGUI:WaitForChild('RewardsList')
		tween:Play()
		
		tween.Completed:Once(function()
			flash:Destroy()
		end)
		
		task.delay(math.max(5, notificationData.Duration or 5.01), function()
			notification:Destroy()
		end)
	end
	
	if notificationData.Sound then
		SoundService:PlayLocalSound(notificationData.Sound)
	else
		SoundService:PlayLocalSound(ReplicatedStorage.Sounds.FX["button.wav"])
	end
end

function module:Error(errorMessage: string)
	module:Notify({
		Type = 'Bottom',
		Message = errorMessage,
		Sound = ReplicatedStorage.Sounds.FX["Error Sound 1"],
		Color = Color3.new(0.776471, 0.0588235, 0.0588235)
	})
end

return module
