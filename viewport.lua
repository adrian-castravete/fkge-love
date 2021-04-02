local lg = love.graphics

local width = 360
local height = 240

local outputWidth = 1280
local outputHeight = 720
local internalCanvas = nil
local offsetX = 0
local offsetY = 0
local scale = 2

local viewport = {}

function viewport.resize(w, h)
	outputWidth = w
	outputHeight = h
	scale = math.max(1, math.floor(math.min(w / width, h / height)))
	offsetX = math.floor((w - width * scale) * 0.5)
	offsetY = math.floor((h - height * scale) * 0.5)
end

function viewport.draw()
	if not internalCanvas then
		return
	end

	lg.push()
	lg.translate(offsetX, offsetY)
	lg.scale(scale, scale)
	lg.draw(internalCanvas, 0, 0)
	lg.pop()

	lg.setCanvas(internalCanvas)
	lg.clear(0, 0, 0)
	lg.setCanvas()
end

function viewport.setup(config)
	width = config.width or width
	height = config.height or height

	viewport.resize(lg.getDimensions())

	internalCanvas = lg.newCanvas(width, height)
	viewport.canvas = internalCanvas
end

return viewport
