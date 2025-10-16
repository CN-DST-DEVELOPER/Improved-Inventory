local function on_slot_item_config_change(self)
    if ThePlayer == self.inst then
        self.inst:DoTaskInTime(0, function()
            self.inst:PushEvent("improved_inventory_helper_rerender")
        end)
    end
end

local ImprovedInventoryHelper_Replica = Class(function(self, inst)
    self.inst = inst
    self._config = net_string(inst.GUID, "improved_inventory_helper._config", "improved_inventory_helper_config_dirty")
    self.config = {item_slot_map = {}, item_image = {}, key_slot_map = {}}
    if TheNet:GetIsClient() or not TheNet:GetServerIsDedicated() then
        inst:ListenForEvent("improved_inventory_helper_config_dirty", function()
            local data = self._config:value()
            if data and data ~= "" then
                self.config = json.decode(data)
            end
        end)
    end
    self._config:set_local(json.encode(self.config))
end, nil, {config = on_slot_item_config_change})

function ImprovedInventoryHelper_Replica:GetSlotItem(slot)
    return self.config.item_slot_map[slot]
end

function ImprovedInventoryHelper_Replica:GetKeyBind(slot)
    return self.config.key_slot_map[slot]
end

function ImprovedInventoryHelper_Replica:GetSlotConfig(slot)
    local config = self.config.item_slot_map[slot] and self.config.item_image[self.config.item_slot_map[slot]]
    if config then
        return config.atlas, config.image
    end
    return nil, nil
end

function ImprovedInventoryHelper_Replica:UpdateAllConfig(config_data)
    if config_data then
        self.config = config_data
        if TheNet:GetIsServer() then
            self._config:set(json.encode(self.config))
        end
    end
end

function ImprovedInventoryHelper_Replica:UpdateWithRPC()
    if TheNet:GetIsServer() then
        self.inst.components.improved_inventory_helper:ReceiveConfigUpdate(self.config)
    else
        SendModRPCToServer(MOD_RPC["IMPROVED_INVENTORY"]["UPDATE_SLOT_BIND_CONFIG"], json.encode(self.config))
    end
end

function ImprovedInventoryHelper_Replica:BindLocal(slot)
    if self.config.item_slot_map[slot] then
        local prefab_old = self.config.item_slot_map[slot]
        self.config.item_slot_map[slot] = nil
        if not table.contains(self.config.item_slot_map, prefab_old) then
            self.config.item_image[prefab_old] = nil
        end
    else
        local slot_item = self.inst.replica.inventory:GetItemInSlot(slot)
        if slot_item then
            self.config.item_slot_map[slot] = slot_item.prefab
            self.config.item_image[slot_item.prefab] = {
                atlas = slot_item.replica.inventoryitem:GetAtlas(),
                image = slot_item.replica.inventoryitem:GetImage(),
            }
        else
            self.config.item_slot_map[slot] = nil
        end
    end
    self.inst:PushEvent("improved_inventory_helper_rerender")
end

function ImprovedInventoryHelper_Replica:BindKey(slot, key)
    self.config.key_slot_map[slot] = key
    self.inst:PushEvent("improved_inventory_helper_rerender")
end

function ImprovedInventoryHelper_Replica:TriggerSlotAction(slot)
    local item = self.inst.replica.inventory:GetItemInSlot(slot)
    self.inst.replica.inventory:UseItemFromInvTile(item)
end

return ImprovedInventoryHelper_Replica
