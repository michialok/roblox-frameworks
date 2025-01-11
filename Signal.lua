--// Lightweight module that creates an object which imitates a RBXScriptSignal

local Signals = {}

local renderStepped = game:GetService("RunService").RenderStepped

function Signals.new()
	local self = {}
	self.__functions = {}
	self.__index = 0
	self.__signals = 0
	self.__waiting = {}
	
	function self:Connect(func)
		self.__signals += 1
		
		local index = self.__signals
		self.__functions[index] = func
		
		local connection = {}
		
		function connection:Disconnect()
			self.__functions[index] = nil
		end

		return setmetatable(connection, {__index = self})
	end
	
	function self:Once(func)
		local connection
		connection = self:Connect(function()
			connection:Disconnect()
			func()
		end)
	end
	
	function self:Fire(...)
		if self.__waiting[self.__index] then
			self.__waiting[self.__index] = table.pack(...)
		end
		
		self.__index += 1

		local args = table.pack(...)
		for _, func in self.__functions do
			task.spawn(func, unpack(args))
		end
	end

	function self:Wait()
		local oldIndex = self.__index

		repeat
			renderStepped:Wait()
		until oldIndex ~= self.__index
		
		local args = table.clone(self.__waiting[oldIndex])
		
		self.__waiting[oldIndex] = nil
		
		return unpack(args)
	end
	
	return self
end

return Signals
