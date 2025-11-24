local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local IonixWebSocket = {}
IonixWebSocket.__index = IonixWebSocket

IonixWebSocket.Config = {
	AUTO_PING = true,
	PING_INTERVAL = 20,
	RECONNECT_BASE = 1,
	RECONNECT_MAX = 30,
	DEBUG = true
}

local function log(...)
	if IonixWebSocket.Config.DEBUG then
		print("[Ionix WS]", ...)
	end
end

-- Cache for usernames and avatars
local UserCache = {}

-- === Get username from userId ===
local function getUsername(userId)
	userId = tonumber(userId)
	if not userId then return "UnknownUser" end
	if UserCache[userId] and UserCache[userId].Username then
		return UserCache[userId].Username
	end

	local username = "User_" .. tostring(userId)
	pcall(function()
		username = Players:GetNameFromUserIdAsync(userId)
	end)

	UserCache[userId] = UserCache[userId] or {}
	UserCache[userId].Username = username
	return username
end

-- === Get avatar headshot ===
local function getHeadshot(userId)
	userId = tonumber(userId)
	if not userId then return nil end
	if UserCache[userId] and UserCache[userId].Avatar then
		return UserCache[userId].Avatar
	end

	local thumbUrl = ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%s&size=420x420&format=Png&isCircular=false"):format(userId)
	local imageUrl = nil

	local success, res = pcall(function()
		return request({
			Url = thumbUrl,
			Method = "GET"
		})
	end)

	if success and res and res.Success and res.Body then
		local body = res.Body:gsub("\\/", "/")
		local match = body:match('"imageUrl"%s*:%s*"(https?://[^"]+)"')
		if match and match:find("rbxcdn", 1, true) then
			imageUrl = match
		end
	end

	UserCache[userId] = UserCache[userId] or {}
	UserCache[userId].Avatar = imageUrl or "https://tr.rbxcdn.com/8b5b2b90a28a35c65a15f660fdad8fa1/420/420/AvatarHeadshot/Png"
	return UserCache[userId].Avatar
end

-- === Build URL ===
local function build_url(host, uid, room)
	local ts = math.floor(os.time())
	return string.format("%s?uid=%s&room=%s&ts=%d",
		host,
		HttpService:UrlEncode(tostring(uid)),
		HttpService:UrlEncode(tostring(room)),
		ts
	)
end

-- === Connect ===
local function connect_ws(url)
	if type(websocket) == "table" and type(websocket.connect) == "function" then
		return websocket.connect(url)
	elseif type(WebSocket) == "table" and type(WebSocket.connect) == "function" then
		return WebSocket.connect(url)
	elseif type(syn) == "table" and syn.websocket and type(syn.websocket.connect) == "function" then
		return syn.websocket.connect(url)
	elseif type(wave) == "table" and wave.websocket and type(wave.websocket.connect) == "function" then
		return wave.websocket.connect(url)
	end
	error("[Ionix WS] No websocket.connect found in this executor")
end

-- === Constructor ===
function IonixWebSocket.new(uid, host, room)
	local self = setmetatable({}, IonixWebSocket)
	self.uid = tostring(uid)
	self.host = tostring(host)
	self.room = tostring(room or "global")

	self.socket = nil
	self.connected = false
	self._stop = false
	self._backoff = IonixWebSocket.Config.RECONNECT_BASE

	self.OnMessage = nil
	self.OnSystem = nil
	self.OnError = nil
	self.OnConnect = nil
	self.OnDisconnect = nil

	return self
end

-- === Connect Once ===
function IonixWebSocket:_connect_once()
	local url = build_url(self.host, self.uid, self.room)
	local ws = connect_ws(url)

	self.socket = ws
	self.connected = true
	self._backoff = IonixWebSocket.Config.RECONNECT_BASE

	log("Connected ->", url)

	if self.OnConnect then pcall(self.OnConnect) end

	if ws.OnMessage and ws.OnMessage.Connect then
		ws.OnMessage:Connect(function(msg)
			self:_on_message(msg)
		end)
	else
		task.spawn(function()
			while self.connected do
				local ok, msg = pcall(function() return ws:Recv() end)
				if ok and msg then
					self:_on_message(msg)
				else
					break
				end
				task.wait(0.05)
			end
		end)
	end

	if ws.OnClose and ws.OnClose.Connect then
		ws.OnClose:Connect(function()
			self.connected = false
			if self.OnDisconnect then pcall(self.OnDisconnect) end
			log("Connection closed.")
		end)
	end

	if IonixWebSocket.Config.AUTO_PING then
		task.spawn(function()
			while self.connected do
				task.wait(IonixWebSocket.Config.PING_INTERVAL)
				pcall(function() ws:Send(HttpService:JSONEncode({ t = "ping" })) end)
			end
		end)
	end
end

function IonixWebSocket:ConnectLoop()
	task.spawn(function()
		while not self._stop do
			local ok, err = pcall(function()
				self:_connect_once()
			end)
			if not ok then
				log("Connect failed:", tostring(err))
				self.connected = false
				pcall(function()
					if self.socket and self.socket.Close then self.socket:Close() end
				end)
			end
			while self.connected and not self._stop do task.wait(0.2) end
			if self._stop then break end
			task.wait(self._backoff)
			self._backoff = math.min(self._backoff * 2, IonixWebSocket.Config.RECONNECT_MAX)
		end
	end)
end

function IonixWebSocket:Disconnect()
	self._stop = true
	self.connected = false
	if self.socket and self.socket.Close then
		pcall(function() self.socket:Close() end)
	end
	if self.OnDisconnect then pcall(self.OnDisconnect) end
end

-- === Send Chat ===
function IonixWebSocket:SendChat(message)
	if not self.connected or not self.socket then
		warn("[Ionix WS] Not connected.")
		return
	end
	if type(message) ~= "string" or #message == 0 then
		return
	end

	local username = getUsername(self.uid)
	local avatar = getHeadshot(self.uid)

	local payload = {
		t = "chat",
		uid = self.uid,
		username = username,
		avatar = avatar,
		msg = message
	}

	local ok, enc = pcall(function()
		return HttpService:JSONEncode(payload)
	end)

	if ok then
		pcall(function() self.socket:Send(enc) end)
	end
end

function IonixWebSocket:_on_message(msg)
	local ok, data = pcall(function() return HttpService:JSONDecode(msg) end)
	if not ok or type(data) ~= "table" then
		log("Raw:", msg)
		return
	end

	if data.t == "chat" then
		if tostring(data.uid) == tostring(self.uid) then return end
		if self.OnMessage then
			local uname = data.username or getUsername(data.uid)
			local head = data.avatar or getHeadshot(data.uid)
			pcall(self.OnMessage, data.uid, uname, head, data.msg, data.ts)
		end

	elseif data.t == "hello" then
		if tostring(data.you) == tostring(self.uid) then
			if self.OnSystem then pcall(self.OnSystem, "Joined room " .. data.room) end
		end

	elseif data.t == "err" then
		if self.OnError then pcall(self.OnError, data.code or "Unknown error") end
	else
		if self.OnSystem then pcall(self.OnSystem, HttpService:JSONEncode(data)) end
	end
end

return IonixWebSocket
