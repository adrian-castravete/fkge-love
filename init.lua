local cpath = ...
local log = require(cpath..".log")
log.level = 'info'
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

local function Scene(name, func)
	if func then
		scenes[name] = {
			init = func,
			entities = {},
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
local function Entity(name)
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

	log.debug("Created entity "..entId.." of kind '"..name.."'")

	return entity
end

local fkge = {
	scene = Scene,
	component = Component,
	entity = Entity,
	system = System,
	c = Component,
	e = Entity,
	s = System,
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

	tick = tick + 1
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

function love.joystickpressed(joy, button)
	fkge.message('input', 'joystickpressed', {joy, button})
end

function love.joystickreleased(joy, button)
	fkge.message('input', 'joystickreleased', {joy, button})
end

function love.joystickaxis(joy, axis, value)
	fkge.message('input', 'joystickaxis', {joy, axis, value})
end

function fkge.game(config)
	lg.setDefaultFilter('nearest', 'nearest')
	vCfg = tableSelect(config, {"width", "height"})
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

function fkge.each(name, func)
	for _, e in ipairs(entities) do
		if e.names[name] then
			func(e)
		end
	end
end

function fkge.stop()
	love.event.quit()
end

return fkge
