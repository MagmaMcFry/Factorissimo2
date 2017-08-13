--[[
Blueprint String
Copyright (c) 2016 David McWilliams, MIT License

This library helps you convert blueprints to text strings, and text strings to blueprints.


Saving Blueprints
-----------------
local BlueprintString = require "blueprintstring.blueprintstring"
local blueprint_table = {
  entities = blueprint.get_blueprint_entities(),
  tiles = blueprint.get_blueprint_tiles(),
  icons = blueprint.blueprint_icons,
  name = blueprint.label,
  myfield = "Add some extra fields if you want",
}
local str = BlueprintString.toString(blueprint_table)


Loading Blueprints
------------------
local BlueprintString = require "blueprintstring.blueprintstring"
local blueprint_table = BlueprintString.fromString(str)
blueprint.set_blueprint_entities(blueprint_table.entities)
blueprint.set_blueprint_tiles(blueprint_table.tiles)
blueprint.blueprint_icons = blueprint_table.icons
blueprint.label = blueprint_table.name or ""


Blueprint Books
------------------
A blueprint book is stored in the book field.
The active blueprint is index 1, other blueprints start from index 2.

local blueprint_table = {
  name = "Label for blueprint book",
  book = {
    [1] = {
      entities = active_inventory[1].get_blueprint_entities(),
      icons = active_inventory[1].blueprint_icons,
    },
    [2] = {
      entities = main_inventory[1].get_blueprint_entities(),
      icons = main_inventory[1].blueprint_icons,
    },
    [3] = {
      entities = main_inventory[2].get_blueprint_entities(),
      icons = main_inventory[2].blueprint_icons,
    },
  }
}

]]--

local serpent = require "serpent0272"
local inflate = require "deflatelua"
local deflate = require "zlib-deflate"
local base64 = require "base64"

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function item_count(t)
  local count = 0
  if (#t >= 2) then return 2 end
  for k,v in pairs(t) do count = count + 1 end
  return count
end

function fix_entities(array)
  if (not array or type(array) ~= "table") then return {} end
  local entities = {}
  local count = 1
  for _, entity in ipairs(array) do
    if (type(entity) == 'table') then
      -- Factorio 0.12 format
      if (entity.conditions and type(entity.conditions) == 'table') then
        if (entity.conditions.circuit) then
          entity.control_behavior = {circuit_condition = entity.conditions.circuit}
        end
        if (entity.conditions.arithmetic) then
          entity.control_behavior = {arithmetic_conditions = entity.conditions.arithmetic}
        end
        if (entity.conditions.decider) then
          entity.control_behavior = {decider_conditions = entity.conditions.decider}
        end
      end
      if (entity.name == "constant-combinator" and entity.filters) then
        entity.control_behavior = {filters = entity.filters}
      end

      -- Factorio 0.13 format
      if (entity.name == "constant-combinator" and entity.control_behavior and type(entity.control_behavior) == 'table' and entity.control_behavior.filters and type(entity.control_behavior.filters) == 'table') then
        for _, filter in pairs(entity.control_behavior.filters) do
          local uint32 = tonumber(filter.count)
          if (uint32 and uint32 >= 2147483648 and uint32 < 4294967296) then
            filter.count = uint32 - 4294967296
          end
        end
      end

      -- Add entity number
      entity.entity_number = count
      entities[count] = entity
      count = count + 1
    end
  end
  return entities
end

function fix_icons(array)
  if (not array or type(array) ~= "table") then return {} end
  if (#array > 1000) then return {} end
  local icons = {}
  local count = 1
  for _, icon in pairs(array) do
    if (count > 4) then break end
    if (type(icon) == "table" and icon.signal) then
      -- Factorio 0.13 format
      table.insert(icons, {index = count, signal = icon.signal})
      count = count + 1
    elseif (type(icon) == "table" and icon.name) then
      -- Factorio 0.12 format
      if (icon.name == "straight-rail" or icon.name == "curved-rail") then
        icon.name = "rail"
      end
      table.insert(icons, {index = count, signal = {type = "item", name = icon.name}})
      count = count + 1
    end
  end
  return icons
end

function fix_name(name)
  if (not name or type(name) ~= "string") then return nil end
  return name:sub(1,100)
end

function remove_useless_fields(entities)
  if (not entities or type(entities) ~= "table") then return end
  for _, entity in ipairs(entities) do
    if (type(entity) ~= "table") then entity = {} end

    -- Entity_number is calculated in fix_entities()
    entity.entity_number = nil

    if (item_count(entity) == 0) then entity = nil end
  end
end

-- ====================================================
-- Public API

local M = {}

M.COMPRESS_STRINGS = true  -- Compress saved strings. Format is gzip + base64.
M.LINE_LENGTH = 120  -- Length of lines in compressed string. 0 means unlimited length.

M.toString = function(blueprint_table)
  remove_useless_fields(blueprint_table.entities)
  blueprint_table.name = fix_name(blueprint_table.name)
  if (blueprint_table.book) then
    for _, page in pairs(blueprint_table.book) do
      remove_useless_fields(page.entities)
      page.name = fix_name(page.name)
    end
  end

  local data = serpent.dump(blueprint_table)
  if (M.COMPRESS_STRINGS) then
    data = deflate.gzip(data)
    data = base64.enc(data)
    if (M.LINE_LENGTH > 0) then
      -- Add line breaks
      data = data:gsub( ("%S"):rep(M.LINE_LENGTH), "%1\n" )
    end
  end
  data = data .. "\n"
  return data
end

M.fromString = function(data)
  data = trim(data)
  if (string.sub(data, 1, 8) ~= "do local") then
    -- Decompress string
    local output = {}
    local input = base64.dec(data)
    local status, result = pcall(inflate.gunzip, { input = input, output = function(byte) output[#output+1] = string.char(byte) end })
    if (status) then
      data = table.concat(output)
    else
      --game.player.print(result)
      return nil
    end
  end

  -- Factorio 0.12 to 0.13 entity rename
  data = data:gsub("[%w-]+", {
    ["basic-accumulator"] = "accumulator",
    ["basic-armor"] = "light-armor",
    ["basic-beacon"] = "beacon",
    ["basic-bullet-magazine"] = "firearm-magazine",
    ["basic-exoskeleton-equipment"] = "exoskeleton-equipment",
    ["basic-grenade"] = "grenade",
    ["basic-inserter"] = "inserter",
    ["basic-laser-defense-equipment"] = "personal-laser-defense-equipment",
    ["basic-mining-drill"] = "electric-mining-drill",
    ["basic-modular-armor"] = "modular-armor",
    ["basic-splitter"] = "splitter",
    ["basic-transport-belt"] = "transport-belt",
    ["basic-transport-belt-to-ground"] = "underground-belt",
    ["express-transport-belt-to-ground"] = "express-underground-belt",
    ["fast-transport-belt-to-ground"] = "fast-underground-belt",
    ["piercing-bullet-magazine"] = "piercing-rounds-magazine",
    ["smart-chest"] = "steel-chest",
    ["smart-inserter"] = "filter-inserter",
  })

  -- Factorio 0.14 to 0.15 entity rename
  data = data:gsub("[%w-]+", {
    ["diesel-locomotive"] = "locomotive",
    ["flame-thrower"] = "flamethrower",
    ["flame-thrower-ammo"] = "flamethrower-ammo",
    ["small-pump"] = "pump",
  })

  local status, result = serpent.load(data)
  if (not status) then
    --game.player.print(result)
    return nil
  end

  result.entities = fix_entities(result.entities)
  result.icons = fix_icons(result.icons)
  result.name = fix_name(result.name)
  if (result.book) then
    for _, page in pairs(result.book) do
      page.entities = fix_entities(page.entities)
      page.icons = fix_icons(page.icons)
      page.name = fix_name(page.name)
    end
  end

  return result
end

return M
