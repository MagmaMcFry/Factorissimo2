function get_circuit_connector_sprites(mainOffset, shadowOffset, connectorNumber)
  local logisticAnimationOffsets = 
  {
    {-0.171875, -0.109375}, -- 0
    {0, 0}, -- 1 (missing)
    {0.015625, 0.015625},
    {0.140625, -0.015625},
    {0.203125, -0.109375},
    {0.140625, -0.203125}, --5
    {0.015625, -0.234375},
    {-0.109375, -0.203125},
    {-0.234375, -0.015625},
    {-0.171875, 0.109375},
    {0.015625, 0.140625}, -- 10
    {0.203125, 0.078125},
    {0.265625, -0.046875},
    {0.203125, -0.171875},
    {0.015625, -0.234375},
    {-0.203125, -0.203125}, --15
    {-0.265625, 0.046875},
    {-0.171875, 0.171875},
    {0.015625, 0.234375},
    {0.171875, 0.171875},
    {0.265625, 0.046875}, -- 20
    {0.171875, -0.109375},
    {-0.015625, -0.171875},
    {-0.203125, -0.078125},
    {-0.203125, 0.140625},
    {-0.140625, 0.234375}, --25
    {0.015625, 0.265625},
    {0.140625, 0.234375},
    {0.203125, 0.140625},
    {0.109375, -0.140625},
    {-0.015625, -0.203125}, --30
    {-0.140625, -0.078125},
  };
  local result = 
  {
    connector_main =
    {
      filename = "__Factorissimo2__/graphics/entity/circuit-connector/circuit-connector-main.png",
      priority = "low",
      width = 28,
      height = 27,
      x = 28*(connectorNumber%8),
      y = 27*(math.floor(connectorNumber/8)),
      shift = {0 + mainOffset[1], 0.015625 + mainOffset[2]},
    },
    led_red =
    {
      filename = "__Factorissimo2__/graphics/entity/circuit-connector/circuit-connector-led-red.png",
      priority = "low",
      width = 20,
      height = 16,
      x = 20*(connectorNumber%8),
      y = 16*(math.floor(connectorNumber/8)),
      shift = {0 + mainOffset[1], -0.03125 + mainOffset[2]},
    },
    led_green =
    {
      filename = "__Factorissimo2__/graphics/entity/circuit-connector/circuit-connector-led-green.png",
      priority = "low",
      width = 20,
      height = 16,
      x = 20*(connectorNumber%8),
      y = 16*(math.floor(connectorNumber/8)),
      shift = {0 + mainOffset[1], -0.03125 + mainOffset[2]},
    },
    led_blue =
    {
      filename = "__Factorissimo2__/graphics/entity/circuit-connector/circuit-connector-led-blue.png",
      priority = "low",
      width = 21,
      height = 22,
      x = 21*(connectorNumber%8),
      y = 22*(math.floor(connectorNumber/8)),
      shift = {-0.015625 + mainOffset[1], 0 + mainOffset[2]},
    },
    
    logistic_animation = 
    {
      filename = "__Factorissimo2__/graphics/entity/circuit-connector/circuit-connector-logistic-animation.png",
      priority = "low",
      blend_mode = "additive",
      line_length = 4,
      width = 43,
      height = 43,
      frame_count = 15,
      shift = {0.015625 + logisticAnimationOffsets[connectorNumber+1][1] + mainOffset[1], -0.234375 + logisticAnimationOffsets[connectorNumber+1][2] + mainOffset[2]},
    },
    
    led_light =
    {
      intensity = 0.8,
      size = 0.9,
    },
    
    blue_led_light_offset = {0 + mainOffset[1], -0.03125 + mainOffset[2]},
    red_green_led_light_offset = {0 + mainOffset[1], -0.15625 + mainOffset[2]},
  };
  
  if (not (shadowOffset == nil)) then
    result.connector_shadow =
    {
      filename = "__Factorissimo2__/graphics/entity/circuit-connector/circuit-connector-shadow.png",
      priority = "low",
      width = 34,
      height = 26,
      x = 34*(connectorNumber%8),
      y = 26*(math.floor(connectorNumber/8)),
      shift = {0.125 + shadowOffset[1], 0.09375 + shadowOffset[2]},
    };
  end
  return result;
end
