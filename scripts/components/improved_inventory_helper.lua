local ImprovedInventoryHelper = Class(function(self, inst)
    self.inst = inst
    self.config = {item_slot_map = {}, item_image = {}}
    self.item_slot_map = {
        -- [prefab] = {
        --     [slot] = {1,2,3},
        --     [atlas] = "images/inventoryimages1.xml",
        --     [image] = "abigail_flower_lunar_level3.tex"
        -- }
    }
    self.marked_slots = {}
end)

function ImprovedInventoryHelper:GetItemSlot(prefab)
    return self.item_slot_map[prefab] and self.item_slot_map[prefab].slots
end

function ImprovedInventoryHelper:ReceiveConfigUpdate(config_data)
    self.config = config_data
    self.inst.replica.improved_inventory_helper:UpdateAllConfig(config_data)

    for i, v in pairs(self.config.item_slot_map) do
        self.item_slot_map[v] = self.item_slot_map[v] or {slots = {}}
        table.insert(self.item_slot_map[v].slots, i)
        table.insert(self.marked_slots, i)
    end

    for k, v in pairs(self.item_slot_map) do
        v.atlas = self.config.item_image[k] and self.config.item_image[k].atlas or nil
        v.image = self.config.item_image[k] and self.config.item_image[k].image or nil
        table.sort(v.slots)
    end
end

function ImprovedInventoryHelper:IsSlotMarked(slot)
    return table.contains(self.marked_slots, slot)
end

return ImprovedInventoryHelper
