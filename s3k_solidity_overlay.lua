----------------------------------------------------------------------------
--      S3K terrain solidity display script
--      Author: Dinopony (@DinoponyRuns)
----------------------------------------------------------------------------
--   This script automatically displays terrain solidity as an overlay
--   when playing Sonic 3 & Knuckles on Bizhawk.   
----------------------------------------------------------------------------

----------------------------------------------------------------------------
--  GLOBAL CONSTANTS
----------------------------------------------------------------------------

GAME_VIEWPORT_WIDTH = 320
GAME_VIEWPORT_HEIGHT = 224
MAX_CHUNKS_ON_SCREEN_X = 4
MAX_CHUNKS_ON_SCREEN_Y = 3

TILE_SIZE_IN_PIXELS = 16
TILE_SIZE_IN_BYTES = 2
TILES_PER_ROW_IN_CHUNK = 8
TILES_PER_COLUMN_IN_CHUNK = 8

----------------------------------------------------------------------------
--  RAM OFFSETS
----------------------------------------------------------------------------

CAMERA_X_ADDR = 0xEE78
CAMERA_Y_ADDR = 0xF616
TIMER_ADDR = 0xFE22

----------------------------------------------------------------------------
--  ROM OFFSETS
----------------------------------------------------------------------------

ANGLE_TABLE_ADDR = 0x96000

----------------------------------------------------------------------------

function is_level_running()
    -- TODO: Improve this check so that demo mode doesn't make title screen colored afterwards
    timer_value = memory.read_u32_be(TIMER_ADDR, "68K RAM")
    return timer_value > 0
end

function get_camera_position()
    cam_x = memory.read_u16_be(CAMERA_X_ADDR, "68K RAM")
    cam_y = memory.read_u16_be(CAMERA_Y_ADDR, "68K RAM")
    return cam_x, cam_y
end

function get_current_collision_layer_addr()
    return memory.read_u32_be(0xF796, "68K RAM")
end

function is_using_alternate_collision_layer()
    current_collision_layer_addr = get_current_collision_layer_addr()
    alternate_layer_addr = memory.read_u32_be(0xF7B8, "68K RAM")
    return current_collision_layer_addr == alternate_layer_addr
end

----------------------------------------------------------------------------

function get_tile_metadata_at(x, y, alternate_collision_layer)
    global_tile_x = math.floor(x / TILE_SIZE_IN_PIXELS)
    global_tile_y = math.floor(y / TILE_SIZE_IN_PIXELS)

    chunk_x = math.floor(global_tile_x / TILES_PER_ROW_IN_CHUNK)
    chunk_y = math.floor(global_tile_y / TILES_PER_COLUMN_IN_CHUNK)

    chunk_row_ptr = memory.read_u16_be(0x8008 + (chunk_y * 4), "68K RAM")
    chunk_id = memory.read_u8(chunk_row_ptr + chunk_x, "68K RAM")
    chunk_ptr = chunk_id * 0x80

    chunk_tile_x = global_tile_x % (TILES_PER_ROW_IN_CHUNK)
    chunk_tile_y = global_tile_y % (TILES_PER_COLUMN_IN_CHUNK)

    tile_ptr = chunk_ptr + (chunk_tile_y * TILES_PER_ROW_IN_CHUNK * TILE_SIZE_IN_BYTES) + (chunk_tile_x * TILE_SIZE_IN_BYTES)
    tile_word = memory.read_u16_be(tile_ptr, "68K RAM")

    if alternate_collision_layer == true then
        solidity = bit.arshift(tile_word, 14)
    else
        solidity = bit.band(bit.arshift(tile_word, 12), 0x3)
    end

    y_flip = bit.band(bit.arshift(tile_word, 11), 0x1)
    x_flip = bit.band(bit.arshift(tile_word, 10), 0x1)
    tile_type_id = bit.band(tile_word, 0x03FF)

    return tile_type_id, solidity, x_flip, y_flip
end

----------------------------------------------------------------------------

function get_color_for_solidity(solidity)
    if solidity == 1 then
        return 0x8800FF00
    elseif solidity == 2 then
        return 0x88FF0000
    elseif solidity == 3 then
        return 0x880000FF
    else
        return 0x00000000
    end
end

----------------------------------------------------------------------------

function draw_solidity_overlay_for_tile(tile_screen_x, tile_screen_y, color, angle_value, x_flip, y_flip)
    gui.drawBox(tile_screen_x-1, tile_screen_y-1, tile_screen_x + TILE_SIZE_IN_PIXELS, tile_screen_y + TILE_SIZE_IN_PIXELS, 0x0, color)
    -- TODO: Use angle value to draw a precise polygon for slopes
    -- TODO: handle x_flip & y_flip
end
----------------------------------------------------------------------------

function draw_solidity()
    -- Prevent solidity overlay from being drawn if no level is being played
    if is_level_running() == false then 
        return
    end

    current_collision_layer_addr = get_current_collision_layer_addr()
    using_alternate_collision_layer = is_using_alternate_collision_layer()

    cam_x, cam_y = get_camera_position()
    cam_end_x = cam_x + GAME_VIEWPORT_WIDTH
    cam_end_y = cam_y + GAME_VIEWPORT_HEIGHT
    start_x = cam_x - (cam_x % TILE_SIZE_IN_PIXELS)
    start_y = cam_y - (cam_y % TILE_SIZE_IN_PIXELS)

    current_x = start_x
    current_y = start_y

    while current_x < cam_end_x do 
        while current_y < cam_end_y do
            tile_type_id, solidity, x_flip, y_flip = get_tile_metadata_at(current_x, current_y, using_alternate_collision_layer)
            color = get_color_for_solidity(solidity)

            if color ~= 0x0 then
                tile_screen_x = current_x - cam_x
                tile_screen_y = current_y - cam_y
                
                angle_type = memory.read_u8(current_collision_layer_addr + (tile_type_id * 2), "MD CART")
                angle_value = memory.read_u8(ANGLE_TABLE_ADDR + angle_type, "MD CART")

                draw_solidity_overlay_for_tile(tile_screen_x, tile_screen_y, color, angle_value, x_flip, y_flip)
            end
            current_y = current_y + TILE_SIZE_IN_PIXELS
        end
        current_x = current_x + TILE_SIZE_IN_PIXELS
        current_y = start_y
    end
end

----------------------------------------------------------------------------

event.onframestart(draw_solidity)
