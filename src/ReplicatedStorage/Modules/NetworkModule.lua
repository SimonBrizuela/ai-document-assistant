--[[
	NetworkModule - Sistema de comunicación Cliente-Servidor
	
	Wrapper sobre RemoteEvents/RemoteFunctions que agrega rate limiting automático,
	validación de tipos, y retry logic. Previene exploits y spam.
	
	Features:
	- Rate limiting (bloquea spam automáticamente)
	- Queue para requests
	- Retry automático si falla
	- Validación de tipos de argumentos
	- Anti-exploit
	- Pattern request/response
	
	Por: 4GP
	v3.0.0
]]

local NetworkModule = {}
NetworkModule.__index = NetworkModule

-- Servicios
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- Configuración
local CONFIG = {
	RateLimitWindow = 5, -- segundos
	MaxRequestsPerWindow = 10,
	RequestTimeout = 10,
	MaxRetries = 3,
	RetryDelay = 1,
	QueueProcessInterval = 0.1
}

-- Estado
local remoteEvents = {}
local remoteFunctions = {}
local rateLimitData = {} -- [playerId][eventName] = { requests = {timestamps}, blocked = false }
local requestQueue = {}
local pendingRequests = {} -- Para responses
local requestIdCounter = 0

-- Validadores de tipo
local TypeValidators = {
	string = function(value)
		return type(value) == "string"
	end,
	
	number = function(value)
		return type(value) == "number"
	end,
	
	boolean = function(value)
		return type(value) == "boolean"
	end,
	
	table = function(value)
		return type(value) == "table"
	end,
	
	Instance = function(value)
		return typeof(value) == "Instance"
	end,
	
	Player = function(value)
		return typeof(value) == "Instance" and value:IsA("Player")
	end,
	
	Vector3 = function(value)
		return typeof(value) == "Vector3"
	end,
	
	CFrame = function(value)
		return typeof(value) == "CFrame"
	end,
	
	Color3 = function(value)
		return typeof(value) == "Color3"
	end
}

--[[ 
	Inicializa el módulo de red
]]
function NetworkModule:Initialize()
	-- Crear carpeta para remotes
	local remotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "RemoteEvents"
		remotesFolder.Parent = ReplicatedStorage
	end
	
	-- Iniciar queue processor solo en cliente
	if IS_CLIENT then
		self:StartQueueProcessor()
	end
	
	print("[NetworkModule] Inicializado (" .. (IS_SERVER and "Server" or "Client") .. ")")
end

--[[ 
	Registra un RemoteEvent
	@param eventName string - Nombre del evento
	@param callback function? - Callback para manejar el evento (server-side)
	@param schema table? - Schema de validación {arg1Type, arg2Type, ...}
	@return RemoteEvent
]]
function NetworkModule:RegisterEvent(eventName, callback, schema)
	if remoteEvents[eventName] then
		return remoteEvents[eventName]
	end
	
	local remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local remoteEvent = remotesFolder:FindFirstChild(eventName)
	
	if not remoteEvent then
		if IS_SERVER then
			remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = remotesFolder
		else
			-- Cliente espera a que el server lo cree
			remoteEvent = remotesFolder:WaitForChild(eventName, 10)
			if not remoteEvent then
				warn("[NetworkModule] Timeout esperando evento:", eventName)
				return nil
			end
		end
	end
	
	remoteEvents[eventName] = {
		Remote = remoteEvent,
		Schema = schema,
		Callback = callback
	}
	
	-- Conectar callback en servidor
	if IS_SERVER and callback then
		remoteEvent.OnServerEvent:Connect(function(player, ...)
			if self:CheckRateLimit(player, eventName) then
				-- Validar argumentos
				if schema and not self:ValidateArgs(schema, {...}) then
					warn(("[NetworkModule] Validación fallida para %s de %s"):format(eventName, player.Name))
					return
				end
				
				-- Ejecutar callback
				local success, err = pcall(callback, player, ...)
				if not success then
					warn(("[NetworkModule] Error en %s: %s"):format(eventName, tostring(err)))
				end
			else
				warn(("[NetworkModule] Rate limit excedido para %s: %s"):format(player.Name, eventName))
			end
		end)
	end
	
	print(("[NetworkModule] Evento registrado: %s"):format(eventName))
	return remoteEvent
end

--[[ 
	Registra un RemoteFunction
	@param functionName string - Nombre de la función
	@param callback function - Callback para manejar la invocación
	@param schema table? - Schema de validación
	@return RemoteFunction
]]
function NetworkModule:RegisterFunction(functionName, callback, schema)
	if remoteFunctions[functionName] then
		return remoteFunctions[functionName]
	end
	
	local remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	local remoteFunction = remotesFolder:FindFirstChild(functionName)
	
	if not remoteFunction then
		if IS_SERVER then
			remoteFunction = Instance.new("RemoteFunction")
			remoteFunction.Name = functionName
			remoteFunction.Parent = remotesFolder
		else
			remoteFunction = remotesFolder:WaitForChild(functionName, 10)
			if not remoteFunction then
				warn("[NetworkModule] Timeout esperando función:", functionName)
				return nil
			end
		end
	end
	
	remoteFunctions[functionName] = {
		Remote = remoteFunction,
		Schema = schema,
		Callback = callback
	}
	
	-- Conectar callback
	if IS_SERVER and callback then
		remoteFunction.OnServerInvoke = function(player, ...)
			if not self:CheckRateLimit(player, functionName) then
				warn(("[NetworkModule] Rate limit excedido para %s: %s"):format(player.Name, functionName))
				return nil
			end
			
			-- Validar argumentos
			if schema and not self:ValidateArgs(schema, {...}) then
				warn(("[NetworkModule] Validación fallida para %s de %s"):format(functionName, player.Name))
				return nil
			end
			
			-- Ejecutar callback
			local success, result = pcall(callback, player, ...)
			if not success then
				warn(("[NetworkModule] Error en %s: %s"):format(functionName, tostring(result)))
				return nil
			end
			
			return result
		end
	elseif IS_CLIENT and callback then
		remoteFunction.OnClientInvoke = callback
	end
	
	print(("[NetworkModule] Función registrada: %s"):format(functionName))
	return remoteFunction
end

--[[ 
	Dispara un evento al servidor (cliente) o a clientes (servidor)
	@param eventName string - Nombre del evento
	@param ... any - Argumentos del evento
]]
function NetworkModule:FireEvent(eventName, ...)
	local eventData = remoteEvents[eventName]
	if not eventData then
		warn("[NetworkModule] Evento no registrado:", eventName)
		return
	end
	
	if IS_CLIENT then
		eventData.Remote:FireServer(...)
	else
		-- Servidor debe especificar target
		warn("[NetworkModule] Usa FireClient o FireAllClients en servidor")
	end
end

--[[ 
	Dispara un evento a un cliente específico (servidor only)
	@param eventName string
	@param player Player
	@param ... any
]]
function NetworkModule:FireClient(eventName, player, ...)
	if not IS_SERVER then
		warn("[NetworkModule] FireClient solo disponible en servidor")
		return
	end
	
	local eventData = remoteEvents[eventName]
	if not eventData then
		warn("[NetworkModule] Evento no registrado:", eventName)
		return
	end
	
	eventData.Remote:FireClient(player, ...)
end

--[[ 
	Dispara un evento a todos los clientes (servidor only)
	@param eventName string
	@param ... any
]]
function NetworkModule:FireAllClients(eventName, ...)
	if not IS_SERVER then
		warn("[NetworkModule] FireAllClients solo disponible en servidor")
		return
	end
	
	local eventData = remoteEvents[eventName]
	if not eventData then
		warn("[NetworkModule] Evento no registrado:", eventName)
		return
	end
	
	eventData.Remote:FireAllClients(...)
end

--[[ 
	Invoca una función remota con retry logic
	@param functionName string
	@param ... any - Argumentos
	@return any? - Resultado de la función
]]
function NetworkModule:InvokeFunction(functionName, ...)
	local funcData = remoteFunctions[functionName]
	if not funcData then
		warn("[NetworkModule] Función no registrada:", functionName)
		return nil
	end
	
	local args = {...}
	local attempts = 0
	
	while attempts < CONFIG.MaxRetries do
		attempts = attempts + 1
		
		local success, result = pcall(function()
			if IS_CLIENT then
				return funcData.Remote:InvokeServer(unpack(args))
			else
				warn("[NetworkModule] InvokeServer no disponible en servidor")
				return nil
			end
		end)
		
		if success then
			return result
		else
			warn(("[NetworkModule] Error invocando %s (intento %d/%d): %s"):format(
				functionName, attempts, CONFIG.MaxRetries, tostring(result)
			))
			
			if attempts < CONFIG.MaxRetries then
				task.wait(CONFIG.RetryDelay * math.pow(2, attempts - 1)) -- Exponential backoff
			end
		end
	end
	
	warn(("[NetworkModule] Max reintentos alcanzados para %s"):format(functionName))
	return nil
end

--[[ 
	Sistema de requests con callback (evita yield en RemoteFunctions)
	@param requestName string
	@param callback function - Callback cuando se reciba respuesta
	@param ... any - Argumentos del request
]]
function NetworkModule:SendRequest(requestName, callback, ...)
	if not IS_CLIENT then
		warn("[NetworkModule] SendRequest solo disponible en cliente")
		return
	end
	
	requestIdCounter = requestIdCounter + 1
	local requestId = requestIdCounter
	
	-- Guardar callback
	pendingRequests[requestId] = {
		Callback = callback,
		Timestamp = tick(),
		RequestName = requestName
	}
	
	-- Enviar request
	local requestEvent = remoteEvents["NetworkRequest"]
	if not requestEvent then
		-- Crear evento si no existe
		self:RegisterEvent("NetworkRequest")
		requestEvent = remoteEvents["NetworkRequest"]
	end
	
	requestEvent.Remote:FireServer(requestId, requestName, ...)
	
	-- Timeout
	task.delay(CONFIG.RequestTimeout, function()
		if pendingRequests[requestId] then
			warn(("[NetworkModule] Request timeout: %s"):format(requestName))
			pendingRequests[requestId] = nil
		end
	end)
end

--[[ 
	Maneja la respuesta de un request (servidor)
	@param player Player
	@param requestId number
	@param requestName string
	@param ... any
]]
function NetworkModule:HandleRequest(player, requestId, requestName, ...)
	-- Buscar handler registrado
	-- Implementación específica del juego
end

--[[ 
	Valida argumentos contra un schema
	@param schema table - Schema de tipos esperados
	@param args table - Argumentos a validar
	@return boolean
]]
function NetworkModule:ValidateArgs(schema, args)
	if #schema ~= #args then
		return false
	end
	
	for i, expectedType in ipairs(schema) do
		local validator = TypeValidators[expectedType]
		if validator then
			if not validator(args[i]) then
				return false
			end
		else
			-- Tipo desconocido, usar type()
			if type(args[i]) ~= expectedType then
				return false
			end
		end
	end
	
	return true
end

--[[ 
	Verifica rate limiting para un jugador
	@param player Player
	@param eventName string
	@return boolean - true si pasa el rate limit
]]
function NetworkModule:CheckRateLimit(player, eventName)
	local userId = player.UserId
	local currentTime = tick()
	
	-- Inicializar si no existe
	if not rateLimitData[userId] then
		rateLimitData[userId] = {}
	end
	
	if not rateLimitData[userId][eventName] then
		rateLimitData[userId][eventName] = {
			requests = {},
			blocked = false
		}
	end
	
	local data = rateLimitData[userId][eventName]
	
	-- Si está bloqueado, verificar si ya pasó el tiempo
	if data.blocked then
		if currentTime - data.blockTime > CONFIG.RateLimitWindow then
			data.blocked = false
			data.requests = {}
		else
			return false
		end
	end
	
	-- Limpiar requests antiguos
	local validRequests = {}
	for _, timestamp in ipairs(data.requests) do
		if currentTime - timestamp < CONFIG.RateLimitWindow then
			table.insert(validRequests, timestamp)
		end
	end
	data.requests = validRequests
	
	-- Verificar límite
	if #data.requests >= CONFIG.MaxRequestsPerWindow then
		data.blocked = true
		data.blockTime = currentTime
		return false
	end
	
	-- Registrar request
	table.insert(data.requests, currentTime)
	return true
end

--[[ 
	Añade un request a la cola (cliente)
	@param request table - Datos del request
]]
function NetworkModule:QueueRequest(request)
	table.insert(requestQueue, request)
end

--[[ 
	Procesador de cola de requests
]]
function NetworkModule:StartQueueProcessor()
	task.spawn(function()
		while true do
			task.wait(CONFIG.QueueProcessInterval)
			
			if #requestQueue > 0 then
				local request = table.remove(requestQueue, 1)
				
				-- Procesar request
				if request.Type == "Event" then
					self:FireEvent(request.Name, unpack(request.Args))
				elseif request.Type == "Function" then
					local result = self:InvokeFunction(request.Name, unpack(request.Args))
					if request.Callback then
						request.Callback(result)
					end
				end
			end
		end
	end)
end

--[[ 
	Limpia datos de rate limit de un jugador (cuando se va)
	@param player Player
]]
function NetworkModule:CleanupPlayer(player)
	local userId = player.UserId
	rateLimitData[userId] = nil
end

--[[ 
	Obtiene estadísticas del sistema
	@return table
]]
function NetworkModule:GetStats()
	local eventCount = 0
	local functionCount = 0
	
	for _ in pairs(remoteEvents) do
		eventCount = eventCount + 1
	end
	
	for _ in pairs(remoteFunctions) do
		functionCount = functionCount + 1
	end
	
	return {
		RegisteredEvents = eventCount,
		RegisteredFunctions = functionCount,
		QueuedRequests = #requestQueue,
		PendingRequests = #pendingRequests,
		IsServer = IS_SERVER
	}
end

return NetworkModule
