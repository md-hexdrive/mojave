local Map = {}
Map.__index = Map
setmetatable( Map, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})


-- Constants
Map.TILE_FREE = 1   -- Tile contains nothing
Map.TILE_WALL = 2   -- Tile is a wall / blocked
Map.TILE_FOOD = 3   -- Tile contains food
Map.TILE_GOLD = 4   -- Tile contains gold
Map.TILE_SNAKE = 5  -- Tile contains a snake


--- Constructor / Factory Function
-- @param table opt A table containing initialization options
-- @return Map
function Map.new( opt )
    
    local self = setmetatable( {}, Map )
    local opt = opt or {}
    
    self.height = opt.height or 20
    self.width = opt.width or 30
    
    -- The map will take up 80% of the game's resolution
    -- and be located in the top left corner.
    local pixelWidth, pixelHeight = love.graphics.getDimensions()
    self.tile_size_x = (pixelWidth * 0.8) / self.width
    self.tile_size_y = (pixelHeight * 0.8) / self.height
    
    -- Generate the tile grid
    self.tiles = {}
    for i = 1, self.height do
        self.tiles[i] = {}
        for j = 1, self.width do
            self.tiles[i][j] = Map.TILE_FREE
        end
    end
    log.debug( string.format( 'generated a grid of size %sx%s', self.width, self.height ) )
    
    return self
    
end


--- Draws the map to the screen.
function Map:draw()
    for i = 1, self.height do
        for j = 1, self.width do
            local x = (j-1) * self.tile_size_x
            local y = (i-1) * self.tile_size_y
            local tile = self.tiles[i][j]
            local radius, mode
            if tile == Map.TILE_FREE then
                love.graphics.setColor(0,0,0,255)
                radius = 0
                mode = 'fill'
            elseif tile == Map.TILE_WALL then
                love.graphics.setColor(0,0,255,255)
                radius = 0
                mode = 'fill'
            elseif tile == Map.TILE_FOOD then
                love.graphics.setColor(0,255,0,255)
                radius = 50
                mode = 'fill'
            elseif tile == Map.TILE_GOLD then
                love.graphics.setColor(255,255,0,255)
                radius = 50
                mode = 'fill'
            elseif tile == Map.TILE_SNAKE then
                love.graphics.setColor(255,0,0,255)
                radius = 0
                mode = 'fill'
            end
            love.graphics.rectangle(
                mode,
                x,
                y,
                self.tile_size_x,
                self.tile_size_y,
                radius,
                radius
            )
        end
    end

end

--- Returns the height of the game board
function Map:getHeight()
    return self.height
end

--- Returns the value of a tile
function Map:getTile( x, y )
    return self.tiles[y][x]
end

--- Returns the width of the game board
function Map:getWidth()
    return self.width
end

--- Sets the value of a tile
function Map:setTile( x, y, value )
    self.tiles[y][x] = value
end

--- Sets a tile of a specific type at a random, free location
function Map:setTileAtRandomFreeLocation( value )
    local x, y
    repeat
        x = love.math.random(self.width)
        y = love.math.random(self.height)
    until self.tiles[y][x] == Map.TILE_FREE
    
    self.tiles[y][x] = value
    return x, y
end


return Map