local cpath = ...
local log = require(cpath..".log")
log.level = 'info'
local lg = love.graphics
local spritesheet = require(cpath..".spritesheet")
local viewport = require(cpath..".viewport")

local function tableSelect(aTable, someFields)
	local outTable = {}
	if not aTable then
		return outTable
	end
	for _, key in ipairs(someFields) do
		local value = aTable[key]
		if value then
			outTable[key] = aTable[key]
		end
	end
	return outTable
end

local function tableUpdate(aTable, anotherTable, toDelete)
	for k, v in pairs(anotherTable) do
		aTable[k] = v
	end
	if toDelete then
		for i, k in ipairs(toDelete) do
			aTable[k] = nil
		end
	end
end

local vCfg = {
	width = 360,
	height = 240,
	background = {0, 0, 0},
	cameraX = 0,
	cameraY = 0,
}
local tick = 0

local events = {}
local components = {}
local systems = {}
local scenes = {}
local entities = {}
local currentScene = {}
local coroutines = {}

local function Scene(name, func)
	if func then
		scenes[name] = {
			init = func,
			entities = {},
			imageCache = {},
		}
		log.debug("Defined scene '"..name.."'")
	else
		local scene = scenes[name]
		if not scene then
			message = "Scene '"..name.."' not yet defined!"
			log.error(message)
			error(message, 2)
		end
		log.info("Loading scene '"..name.."'...")
		currentScene = scene
		scene.init()
		log.debug("Loaded scene '"..name.."'")
	end
end

local function Component(name, parents, data, toDelete)
	local comp = nil

	if not data and parents and type(parents) == 'table' then
		data = parents
		parents = nil
	end

	if data or parents then
		comp = {}
		local names = {}
		if parents then
			for parent in string.gmatch(parents, '[^,%s*]+') do
				local pcomp = Component(parent)
				if not pcomp then
					pcomp = Component(parent, {})
				end
				local pnames = pcomp.names
				tableUpdate(comp, pcomp)
				for _, pname in ipairs(pnames) do
					names[#names+1] = pname
				end
			end
		end
		if data then
			tableUpdate(comp, data, toDelete)
		end
		components[name] = comp
		names[#names+1] = name
		comp.names = names
		comp.name = name
		log.debug("Defined component '"..name.."'")
	else
		comp = components[name]
	end

	return comp
end

local function System(name, data)
	local system = nil

	if data then
		systems[name] = data
		log.debug("Defined system '"..name.."'")
	else
		system = systems[name]
		if not system then
			log.error("System '"..name.."' is not defined.")
		end
	end

	return system
end

local entId = 0
local function Entity(name, ...)
	entId = entId + 1

	local entity = {
		id = entId,
	}
	function entity.attr (obj)
		tableUpdate(entity, obj)
		return entity
	end

	local names = {}
	for cname in string.gmatch(name, '[^,%s*]+') do
		local pcomp = Component(cname)
		if not pcomp then
			message = "Component '"..cname.."' does not exist."
			log.error(message)
			error(message, 2)
		end
		for _, pname in ipairs(pcomp.names) do
			names[pname] = true
		end
		tableUpdate(entity, pcomp)
		names[cname] = true
	end
	entity.names = names

	if currentScene then
		entities = currentScene.entities
	else
		log.warn("Creating entity in global scope; consider creating a scene.")
	end

	entities[#entities+1] = entity

	if entity.init then
		entity.init(entity, ...)
	end

	log.debug("Created entity "..entId.." of kind '"..name.."'")

	return entity
end

local function ComponentSystem(config)
	local name = config.name or error("Component name not given", 2)
	local parents = config.parents
	local sysData = config.system
	local toDelete = config.delete
	tableUpdate(config, {}, {'name', 'parents', 'system', 'delete'})
	local component = Component(name, parents, config, toDelete)
	local system = nil
	if sysData then
		system = System(name, sysData)
	end

	return component, system
end

local fkge = {
	scene = Scene,
	component = Component,
	entity = Entity,
	system = System,
	componentSystem = ComponentSystem,
	c = Component,
	e = Entity,
	s = System,
	cs = ComponentSystem,
}

function love.load()
end

function love.draw()
	viewport.draw()
end

local function draw()
end

function love.update(dt)
	lg.setCanvas(viewport.canvas)
	lg.clear(vCfg.background)

	tick = tick + 1

	local newCoroutines = {}
	for _, co in ipairs(coroutines) do
		if coroutine.resume(co, dt) then
			newCoroutines[#newCoroutines+1] = co
		end
	end
	coroutines = newCoroutines
	if #coroutines > 0 then
		log.debug(#coroutines .. " pending.")
	end

	local newEntities = {}
	for _, e in ipairs(entities) do
		for name, func in pairs(systems) do
			if e.names[name] then
				local eevents = events['tick'..tick] or {}
				func(e, eevents[name] or {}, dt, tick)
			end
		end
		if not e.destroy then
			newEntities[#newEntities + 1] = e
		end
	end
	entities = newEntities
	if currentScene then
		currentScene.entities = entities
	end
	events['tick'..tick] = nil

	lg.setColor(1, 1, 1)
	lg.setCanvas()
end

function love.resize(w, h)
	viewport.resize(w, h)
end

function love.keypressed(key)
	fkge.message('input', 'keypressed', key)
end

function love.keyreleased(key)
	fkge.message('input', 'keyreleased', key)
end

local function mouseToMapCoords(x, y)
	local v = viewport
	return (x - v.offsetX) / v.scale, (y - v.offsetY) / v.scale
end

for _, part in ipairs {'pressed', 'released', 'moved'} do
	local name = 'mouse' .. part
	love[name] = function(x, y, ...)
		local sx, sy = mouseToMapCoords(x, y)
		fkge.message('input', name, {sx, sy, ...})
	end
end

for _, part in ipairs {'pressed', 'released', 'moved'} do
	local name = 'touch' .. part
	love[name] = function(tid, x, y, ...)
		local sx, sy = mouseToMapCoords(x, y)
		fkge.message('input', name, {tid, sx, sy, ...})
	end
end

for _, name in ipairs {
	'joystickpressed', 'joystickreleased', 'joystickaxis',
	'gamepadpressed', 'gamepadreleased', 'gamepadaxis',
	'wheelmoved',
} do
	love[name] = function (...)
		fkge.message('input', name, {...})
	end
end

function fkge.game(config)
	local config = config or {}

	lg.setDefaultFilter('nearest', 'nearest')
	vCfg = tableSelect(config, {"width", "height", "background"})
	viewport.setup(vCfg)

	if config.logLevel then
		log.level = config.logLevel
	end

	local tCfg = config.sprites or nil
	if tCfg then
		local sprs = {}
		for imgName, cfg in pairs(tCfg) do
			sprs[imgName] = spritesheet.build(cfg)
		end
		fkge.sprites = sprs
	end
end

function fkge.message(ename, name, data)
	local tickName = 'tick'..(tick+1)
	local tickEvents = events[tickName]
	if not tickEvents then
		tickEvents = {}
	end

	local nameEvents = tickEvents[ename]
	if not nameEvents then
		nameEvents = {}
	end
	if not nameEvents[name] then
		nameEvents[name] = {}
	end
	local nameEventsList = nameEvents[name]
	if not data then
		data = true
	end
	nameEventsList[#nameEventsList+1] = data
	nameEvents[name] = nameEventsList
	tickEvents[ename] = nameEvents
	events[tickName] = tickEvents
end

function fkge.count(name)
	local count = 0
	for _, e in ipairs(entities) do
		if not name or e.names[name] then
			count = count + 1
		end
	end
	return count
end

function fkge.each(name, func)
	for _, e in ipairs(entities) do
		if not name or e.names[name] then
			func(e)
		end
	end
end

function fkge.find(name, func)
	for _, e in ipairs(entities) do
		if not name or e.names[name] then
			local f = func(e)
			if f then
				return f
			end
		end
	end
	return nil
end

function fkge.map(name, func)
	local results = {}
	for _, e in ipairs(entities) do
		if not name or e.names[name] then
			results[#results+1] = func(e)
		end
	end
	return results
end

function fkge.reduce(name, func, accum)
	local accum = accum
	for _, e in ipairs(entities) do
		if not name or e.names[name] then
			local res = func(e, accum)
			if res then
				accum = res
			end
		end
	end
	return accum
end

function fkge.lerp(a, b, r)
	return a + r * (b - a)
end

function fkge.anim(time, progress, callback)
	local co = coroutine.create(function (dt)
		local p = dt
		while p <= time do
			local r = p / time
			local v = progress(r) or r
			dt = coroutine.yield(r)
			p = p + dt
		end
		if callback then
			callback()
		end
	end)
	coroutines[#coroutines+1] = co
end

function fkge.stop()
	love.event.quit()
end

function fkge.wipe(cb)
	if currentScene then
		for _, e in ipairs(entities) do
			e.destroy = true
		end
		currentScene.entities = {}
		entities = currentScene.entities
		cb()
	end
end

function fkge.spr(config)
	return spritesheet.build(config, currentScene.imageCache)
end

return fkge