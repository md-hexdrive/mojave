json = require 'thirdparty.dkjson'
http = require 'socket.http'
inspect = require 'thirdparty.inspect'

local thread = love._curthread

local channel = love.thread.getChannel( "worker" )
local updateChannel = love.thread.getChannel( "worker.update" )

function update(opts)
    while true do
        local boardState = channel:pop()
        -- print( inspect( boardState ) )

        if boardState ~= nil then
            local mBoardState = json.decode( boardState )
            local snakes = mBoardState[ 'snakes' ]
            local update = {}

            for i = 1, #snakes do
                local snake = snakes[i]
                local snakeResponse = {}

                if snake[ 'type' ] == 3 then
                    -- 2017 API
                    api( snake, 'move', json.encode( self:getState2017( mBoardState, snake ) ) )
                elseif snake[ 'type' ] == 6 then
                    -- 2018 API
                    snakeResponse = api( snake, 'move', json.encode( getState2018( mBoardState, snake ) ) )
                    -- print( inspect(snakeResponse) )
                elseif snake[ 'type' ] == 4 then
                    -- 2016 API
                    local endpoint = 'move'
                    if boardState[ 'turn' ] == 1 then
                        endpoint = 'start'
                    end

                    api( endpoint, json.encode( self:getState2016( snake[ 'slot' ] ) ) )
                elseif snake[ 'type' ] == 5 then
                    local success, response_data = coroutine.resume(
                        snake.thread,
                        self:getState2017( snake[ 'slot' ] )
                    )

                    if not success then
                        self:log( string.format( 'ROBOSNAKE: %s', response_data ), 'fatal' )
                    else
                        if response_data[ 'move' ] ~= nil then
                            snake:setDirection( response_data[ 'move' ] )
                        end

                        if response_data[ 'taunt' ] ~= nil then
                            if response_data[ 'taunt' ] ~= snake.taunt then
                                snake.taunt = response_data[ 'taunt' ]
                                if config[ 'gameplay' ][ 'enableTaunts' ] then
                                    gameLog( string.format( '%s says: %s', snake.name, snake.taunt ) )
                                end
                            end
                        end
                    end
                end

                update[ snake[ 'id' ] ] = snakeResponse
            end

            updateChannel:push( json.encode( update ) )
        end
    end
end

--- Executes a HTTP request to the BattleSnake server
--- (remember, the game board is a *client*, and the snakes are *servers*
--- contrary to what you might expect!)
-- @param endpoint The snake server's HTTP API endpoint
-- @param data The data to send to the endpoint
function api( snake, endpoint, data )

    local request_url = snake[ 'url' ] .. '/' .. endpoint
    -- gameLog( string.format( 'Request URL: %s', request_url ), 'debug' )
    -- gameLog( string.format( 'POST body: %s', data ), 'debug' )

    --[[
        The version of LuaSocket bundled with LÖVE has a bug
        where the http port will not get added to the Host header,
        which is a violation of the HTTP spec. Most web servers don't
        care - however - this breaks Flask, which interprets the
        spec very strictly and is also used by a lot of snakes.

        We can work around this by manually parsing the URL,
        generating a Host header, and explicitly setting it on the request.

        See https://github.com/diegonehab/luasocket/pull/74 for more info.
    ]]
    local parsed = socket.url.parse( request_url )
    local host = parsed[ 'host' ]
    if parsed[ 'port' ] then host = host .. ':' .. parsed[ 'port' ] end

    -- make the request
    local response_body = {}
    local res, code, response_headers, status
    if endpoint == '' then
        res, code, response_headers, status = http.request({
            url = request_url,
            method = "GET",
            headers =
            {
              [ "Content-Type" ] = "application/json",
              [ "Host" ] = host
            },
            sink = ltn12.sink.table( response_body )
        })
    else
        res, code, response_headers, status = http.request({
            url = request_url,
            method = "POST",
            headers =
            {
              [ "Content-Type" ] = "application/json",
              [ "Content-Length" ] = data:len(),
              [ "Host" ] = host
            },
            source = ltn12.source.string( data ),
            sink = ltn12.sink.table( response_body )
        })
    end

    -- handle the response
    if status then
        -- gameLog( string.format( 'Response Code: %s', code ), 'debug' )
        -- gameLog( string.format( 'Response Status: %s', status ), 'debug' )
        -- gameLog( string.format( 'Response body: %s', table.concat( response_body ) ), 'debug' )
        local response_data = json.decode( table.concat( response_body ) )

        if response_data then
            if response_data[ 'name' ] ~= nil then
                snake[ 'name' ] = response_data[ 'name' ]
            end
            if response_data[ 'move' ] ~= nil then
                snake[ 'direction' ] = response_data[ 'move' ]
            end
            if response_data[ 'taunt' ] ~= nil then
                if ( snake[ 'type' ] == 6 and endpoint == 'start' ) or ( snake[ 'type' ] ~= 6 ) then
                    if response_data[ 'taunt' ] ~= snake[ 'taunt' ] then
                        snake[ 'taunt' ] = response_data[ 'taunt' ]

                        -- if config[ 'gameplay' ][ 'enableTaunts' ] then
                        --     gameLog( string.format( '%s says: %s', self.name, snake[ 'taunt' ] ) )
                        -- end
                    end
                end
            end

            -- if response_data[ 'color' ] ~= nil then
            --     self:setColor( response_data[ 'color' ], true )
            -- end

            -- if response_data[ 'head_type' ] ~= nil then
            --     if response_data[ 'head_type' ] == 'bendr' then
            --         self.head = snakeHeads[1]
            --     elseif response_data[ 'head_type' ] == 'dead' then
            --         self.head = snakeHeads[2]
            --     elseif response_data[ 'head_type' ] == 'fang' then
            --         self.head = snakeHeads[3]
            --     elseif response_data[ 'head_type' ] == 'pixel' then
            --         self.head = snakeHeads[4]
            --     elseif response_data[ 'head_type' ] == 'regular' then
            --         self.head = snakeHeads[5]
            --     elseif response_data[ 'head_type' ] == 'safe' then
            --         self.head = snakeHeads[6]
            --     elseif response_data[ 'head_type' ] == 'sand-worm' then
            --         self.head = snakeHeads[7]
            --     elseif response_data[ 'head_type' ] == 'shades' then
            --         self.head = snakeHeads[8]
            --     elseif response_data[ 'head_type' ] == 'smile' then
            --         self.head = snakeHeads[9]
            --     elseif response_data[ 'head_type' ] == 'tongue' then
            --         self.head = snakeHeads[10]
            --     end
            -- end

            -- if response_data[ 'tail_type' ] ~= nil then
            --     if response_data[ 'tail_type' ] == 'small-rattle' then
            --         self.tail = snakeTails[1]
            --     elseif response_data[ 'tail_type' ] == 'skinny-tail' then
            --         self.tail = snakeTails[2]
            --     elseif response_data[ 'tail_type' ] == 'round-bum' then
            --         self.tail = snakeTails[3]
            --     elseif response_data[ 'tail_type' ] == 'regular' then
            --         self.tail = snakeTails[4]
            --     elseif response_data[ 'tail_type' ] == 'pixel' then
            --         self.tail = snakeTails[5]
            --     elseif response_data[ 'tail_type' ] == 'freckled' then
            --         self.tail = snakeTails[6]
            --     elseif response_data[ 'tail_type' ] == 'fat-rattle' then
            --         self.tail = snakeTails[7]
            --     elseif response_data[ 'tail_type' ] == 'curled' then
            --         self.tail = snakeTails[8]
            --     elseif response_data[ 'tail_type' ] == 'block-bum' then
            --         self.tail = snakeTails[9]
            --     end
            -- end

            -- if response_data[ 'head_url' ] ~= nil then
            --     self:setAvatar( response_data[ 'head_url' ] )
            -- elseif response_data[ 'head' ] ~= nil then
            --     self:setAvatar( response_data[ 'head' ] )
            -- end
        end
    else
        -- no response from api call in allowed time
        gameLog( string.format( '%s: No response from API call in allowed time', self.name ), 'error' )

        -- choose a random move for the snake if a move request timed out
        if endpoint == 'move' and self.type ~= 4 then
            self.direction = self.DIRECTIONS[love.math.random(4)]
            gameLog( string.format( '"%s" direction changed to "%s"', self.name, self.direction ), 'debug' )
        end
    end

    return snake
end

function getState2018( board, snake )
    -- print( inspect( board ) )
    local snakes = board[ 'snakes' ] or {}
    local mySnakes = {}
    local you = {}

    for i = 1, #snakes do
        local positionZeroBasedCoords = {}

        for j = 1, #snakes[i].position do
            table.insert( positionZeroBasedCoords, {
                object = 'point',
                x = snakes[i][ 'position' ][j][1] - 1,
                y = snakes[i][ 'position' ][j][2] - 1
            })
        end

        local snakeObj = {
            body = {
                object = 'list',
                data = positionZeroBasedCoords
            },
            health = snakes[i].health,
            id = snakes[i].id,
            length = #positionZeroBasedCoords,
            name = snakes[i].name,
            object = 'snake',
            taunt = snakes[i].taunt
        }

        if snake[ 'slot' ] == snakes[i][ 'slot' ] then
            you = snakeObj
        end

        table.insert( mySnakes, snakeObj )
    end

    local foodZeroBasedCoords = {}

    for i = 1, #board[ 'food' ] do
        table.insert( foodZeroBasedCoords, {
            object = 'point',
            x = board[ 'food' ][i][1] - 1,
            y = board[ 'food' ][i][2] - 1
        })
    end

    return {
        object = 'world',
        id = board[ 'id' ],
        you = you,
        snakes = {
            object = 'list',
            data = mySnakes
        },
        height = board[ 'height' ],
        width = board[ 'width' ],
        turn = board[ 'turn' ],
        food = {
            object = 'list',
            data = foodZeroBasedCoords
        }
    }

end

-- channel:demand( "run" )
update()
