--[[
-- Custom Warp Points (CWP) - Command Module
-- ===========================================
-- Provides in-game warp point persistence commands
-- 
-- Requirements:
--   1. SQL table created via modules/custom/sql/cwp_warp_points.sql  
--   2. C++ storage backend linked into build (modules/custom/cpp/cwp_storage.cpp)
--   3. Entry in modules/init.txt to register this module
--
-- Commands:
--   !cwp set <1-10> - Save current position as warp point #<n>
--   !cwp go <1-10>  - Warp from stored warp point #<n> (and delete)
--   !cwp list       - List all saved warp points
-- ]]

local Module = xi.module and require('modules/module_utils') or _G._module or {}
if type(Module) ~= 'table' then Module = { MODULE_NAME = 'cwp_command' } end

--[[
-- Registration: collect commands during load, publish after all modules loaded
-- ]]

_G.__registerCommands = _G.__registerCommands or {}
_G.__registerCommands[Module.MODULE_NAME] = {}

local function _register_command(name, permission, param_spec)
    local entry = {
        name = name,
        cmdprops = { permission = permission or 0, parameters = param_spec or '' },
    }
    
    table.insert(_G.__registerCommands[Module.MODULE_NAME], entry)
end

--[[
-- Command: !cwp set <slot_id> - Save player's current position
-- Parameter spec 'i' indicates integer parameter (the slot id)
-- ]]

_G['cwp_set_obj'] = {
    cmdprops = { 
        permission = 3,   -- Allow officer/GM level to use this command
        parameters = 'i', -- Integer parameter: slot number
    },
    
    -- This function is called when the command is triggered by a player
    onTrigger = function(player, ...)
        local playerId = player:getId()
        
        -- Check if player has a current position to save
        local coords = _G.cwp_coords and _G.cwp_coords[playerId] or {}
        
        if not coords.x or coords.x == 0 and coords.y == 0 then
            player:printToPlayer("No active position available. Must move in world first.", 
                                xi.msg.channel.SYSTEM_3, '')
            return true
        end
        
        -- Extract slot parameter from args table
        local args = ... and { ... }
        local slot = args[1] or 0
        
        -- Validate slot is within range (1-10)
        if not slot or slot < 1 or slot > 10 then
            player:printToPlayer("Invalid slot. Must be a number from 1 to 10.", 
                                xi.msg.channel.SYSTEM_3, '')
            return true
        end
    
        -- Get current coordinates from world position
        local x_pos = player:getPos().x or 0
        local y_pos = player:getPos().y or 0
        local z_pos = player:getPos().z or 0
        
        -- Store warp point in database  
        _G._cwp_store(playerId, slot, x_pos, y_pos, z_pos)
    
        player:printToPlayer(string.format("Warp point #%d saved to slot %d.",
                                            x_pos, y_pos, z_pos),
                            xi.msg.channel.SYSTEM_3, '')
    
        return true
    end
}

--[[
-- Command: !cwp go <slot_id> - Warp from stored position (deletes after use)
-- ]]

_G['cwp_go_obj'] = {
    cmdprops = { 
        permission = 4,   -- Admin/GM only for warp deletion
        parameters = 'i', 
    },
    
    onTrigger = function(player, ...)
        local playerId = player:getId()
        local args = ... and { ... }
        
        -- Get slot parameter
        local slot = args[1] or 0
        
        if not slot or slot < 1 or slot > 10 then
            player:printToPlayer("Invalid slot. Must be 1-10.", 
                                xi.msg.channel.SYSTEM_3, '')
        elseif not _G._cwp_check(playerId, slot) then
            player:printToPlayer(string.format("Warp point #%d does not exist for you.", 
                                               slot),
                               xi.msg.channel.SYSTEM_3, '')
            return true
        end
        
        -- Fetch stored coordinates from DB and remove the warp point
        local x_pos, y_pos, z_pos = _G._cwp_fetch(playerId, slot)
        
        if not (x_pos and y_pos and z_pos) then
            player:printToPlayer(string.format("Warp point #%d deleted successfully.", 
                                               slot),
                               xi.msg.channel.SYSTEM_3, '')
            return true
        end
        
        -- Execute warp using stored coordinates
        player:teleport(slotPos, x_pos, y_pos, z_pos)
        
        player:printToPlayer(string.format("Warped to %s (%.1f, %.1f, %.1f).",
                                            slotPos or "position", 
                                            x_pos, y_pos, z_pos),
                            xi.msg.channel.SYSTEM_3, '')
    
        return true
    end
}

--[[
-- Command: !cwp list - List all active warp points
-- ]]

_G['cwp_list_obj'] = {
    cmdprops = { 
        permission = 2,   -- Officer level can use this
        parameters = '',  -- No parameters needed
    },
    
    onTrigger = function(player, ...)
        local playerId = player:getId()
        
        -- Get all stored warp points for this player
        local slotData = _G._cwp_list(playerId)
        
        if not slotData or #slotData == 0 then
            player:printToPlayer("No warp points saved.", xi.msg.channel.SYSTEM_3, '')
            return true
        end
        
        player:printToPlayer(string.format("Showing %d of 10 available warp slots:",
                                            #slotData and math.min(#slotData, 10)),
                            xi.msg.channel.SYSTEM_3, '')
        
        -- Display each stored warp point
        for _, slot in ipairs(slotData or {}) do 
            if slot then
                
                local zoneName = slot.zone_name or "undefined"
                
                player:printToPlayer(string.format("Warp #%d - %s (%.1f, %.1f, %.1f)",
                                                    slot.slot_id, 
                                                    type(zoneName) == 'string' and zoneName 
                                                            or tostring(slotPos or "null"),
                                                    slot.x_pos or 0,
                                                    slot.y_pos or 0,  
                                                     slot.z_pos or 0),
                                    xi.msg.channel.SYSTEM_3, '')

            end
        end
        
        player:printToPlayer("List complete.", xi.msg.channel.SYSTEM_3, '')
    
        return true
    end
}

--[[
-- Publish registered commands once the loader has finished loading all modules
-- ]]

_PUBLISH_COMMAND = function(self)
    for _, entry in pairs(_G.__registerCommands or {}) do
        for _, cmdEntry in ipairs(entry or {}) do
            local obj = cmdEntry.obj or _G[cmdEntry.name .. '_obj']
            
            if obj and obj.onTrigger then
                xi.module.commandRegistry[#xi.module.commandRegistry + 1] = { 
                    name = cmdEntry.name,
                    command = obj
                }
            end
        end
    end
end

_PUBLISH_COMMAND(Module.MODULE_NAME)
