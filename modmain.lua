Assets = {
    Asset("IMAGE", "images/equip_slot_backpack.tex"),
    Asset("ATLAS", "images/equip_slot_backpack.xml"),
    Asset("IMAGE", "images/equip_slot_cloth.tex"),
    Asset("ATLAS", "images/equip_slot_cloth.xml"),
    Asset("IMAGE", "images/equip_slot_neck.tex"),
    Asset("ATLAS", "images/equip_slot_neck.xml"),
    Asset("IMAGE", "images/equip_slot_error_bd.tex"),
    Asset("ATLAS", "images/equip_slot_error_bd.xml"),
    Asset("IMAGE", "images/locked.tex"),
    Asset("ATLAS", "images/locked.xml"),
    Asset("IMAGE", "images/unlocked.tex"),
    Asset("ATLAS", "images/unlocked.xml"),
    Asset("IMAGE", "images/setting.tex"),
    Asset("ATLAS", "images/setting.xml"),
}

local BASE_EQUIPSLOTS = {HANDS = "hands", BODY = "body", HEAD = "head", BEARD = "beard"}

local ADDITIONAL_EQUIPSLOTS = {CLOTHING = "clothing", BACKPACK = "backpack", NECK = "neck"}

GLOBAL.EQUIPSLOTS = GLOBAL.MergeMaps(BASE_EQUIPSLOTS, ADDITIONAL_EQUIPSLOTS)
local AMULET_LIST = {"amulet", "blueamulet", "purpleamulet", "orangeamulet", "greenamulet", "yellowamulet"}

AddReplicableComponent("improved_inventory_helper")

local function OnUpdateSlotBindRPC(player, config)
    if player and player.components.improved_inventory_helper then
        player.components.improved_inventory_helper:ReceiveConfigUpdate(GLOBAL.json.decode(config))
    end
end

AddModRPCHandler("IMPROVED_INVENTORY", "UPDATE_SLOT_BIND_CONFIG", OnUpdateSlotBindRPC)

if GLOBAL.TheNet:GetIsServer() then
    local UpvalueHacker = GLOBAL.require("upvaluehacker")

    AddComponentPostInit("equippable", function(self, inst)
        function self:InitImprovedInventoryItem()
            if self.equipslot == GLOBAL.EQUIPSLOTS.BODY then
                local equipslot_improved = nil
                if inst:HasTag("improved_inventory_armor") then
                    equipslot_improved = GLOBAL.EQUIPSLOTS.BODY
                elseif inst:HasTag("improved_inventory_container") and
                    not (inst:HasTag("improved_inventory_insulator") and inst.components.container:GetNumSlots() < 6) then -- has too small container, should be a secondary backpack
                    equipslot_improved = GLOBAL.EQUIPSLOTS.BACKPACK
                elseif inst:HasTag("improved_inventory_insulator") then
                    equipslot_improved = GLOBAL.EQUIPSLOTS.CLOTHING
                elseif inst:HasTag("improved_inventory_neck") then
                    equipslot_improved = GLOBAL.EQUIPSLOTS.NECK
                else
                    equipslot_improved = GLOBAL.EQUIPSLOTS.BODY
                end
                self.equipslot = equipslot_improved
            end
        end

        inst:DoTaskInTime(0, function() -- in case some prefabs add equippable component conditionally
            self:InitImprovedInventoryItem()
        end)
    end)

    AddComponentPostInit("armor", function(self, inst)
        inst:AddTag("improved_inventory_armor")
    end)

    AddComponentPostInit("insulator", function(self, inst)
        inst:AddTag("improved_inventory_insulator")
    end)

    AddComponentPostInit("container", function(self, inst)
        inst:AddTag("improved_inventory_container")
    end)

    AddPrefabPostInitAny(function(inst)
        if table.contains(AMULET_LIST, inst.prefab) then
            inst:AddTag("improved_inventory_neck")
        end
        if inst.components.equippable ~= nil then
            inst.components.equippable:InitImprovedInventoryItem()
        end
    end)

    AddComponentPostInit("inventory", function(self, inst)
        local equipslots = {}

        GLOBAL.setmetatable(equipslots, {
            __index = function(t, k)
                if table.contains(BASE_EQUIPSLOTS, k) then
                    return GLOBAL.rawget(t, k)
                elseif not inst:HasTag("player") and table.contains(ADDITIONAL_EQUIPSLOTS, k) then
                    return GLOBAL.rawget(t, GLOBAL.EQUIPSLOTS.BODY)
                end
            end,
            __newindex = function(t, k, v)
                if table.contains(ADDITIONAL_EQUIPSLOTS, k) and not inst:HasTag("player") then
                    GLOBAL.rawset(t, GLOBAL.EQUIPSLOTS.BODY, v)
                else
                    GLOBAL.rawset(t, k, v)
                end
            end,
        })
        GLOBAL.rawset(self, "equipslots", equipslots)
    end)

    local function iscoat(item)
        return
            item.components.insulator and item.components.insulator:GetInsulation() >= GLOBAL.TUNING.INSULATION_SMALL and
                item.components.insulator:GetType() == GLOBAL.SEASONS.WINTER and item.components.equippable and
                (item.components.equippable.equipslot == GLOBAL.EQUIPSLOTS.CLOTHING or
                    item.components.equippable.equipslot == GLOBAL.EQUIPSLOTS.BODY)
    end

    AddPrefabPostInit("hermitcrab", function(inst)
        inst.iscoat = iscoat
        UpvalueHacker.SetUpvalue(GLOBAL.Prefabs.hermitcrab.fn, iscoat, "iscoat")
    end)

    AddPlayerPostInit(function(inst)
        inst:AddComponent("improved_inventory_helper")
        local oldGetNextAvailableSlot = inst.components.inventory.GetNextAvailableSlot
        -- 1. Preferred slot first. If the preferred slot is occupied, it's likely manually placed, so don't handle it.
        -- 2. If all preferred slots are occupied or there is no preferred slot at all, don't occupy someone else's preferred slot. 
        --    Try to prioritize stacking in non-preferred slots first, then use unmarked empty slots
        -- 3. If nothing else works, use the default logic. 
        function inst.components.inventory:GetNextAvailableSlot(item)
            local preferred_slots = inst.components.improved_inventory_helper:GetItemSlot(item.prefab)
            if preferred_slots then
                for _, preferred_slot in ipairs(preferred_slots) do
                    if preferred_slot <= self.inst.components.inventory.maxslots and
                        self.inst.components.inventory.itemslots[preferred_slot] == nil then
                        return preferred_slot, self.itemslots
                    end
                end
            end
            for k = 1, self:GetNumSlots() do
                if not inst.components.improved_inventory_helper:IsSlotMarked(k) and self:CanTakeItemInSlot(item, k) and
                    (not self.itemslots[k] or self.itemslots[k].prefab == item.prefab and self.itemslots[k].skinname ==
                        item.skinname and self.itemslots[k].components.stackable and
                        not self.itemslots[k].components.stackable:IsFull()) then
                    return k, self.itemslots
                end
            end
            local overflow = self:GetOverflowContainer()
            if overflow ~= nil then
                if item.components.inventoryitem == nil or not item.components.inventoryitem.canonlygoinpocket and
                    (not item.components.inventoryitem.canonlygoinpocketorpocketcontainers or
                        overflow.inst.components.inventoryitem and
                        overflow.inst.components.inventoryitem.canonlygoinpocket) then
                    for k, v in pairs(overflow.slots) do
                        if v.prefab == item.prefab and v.skinname == item.skinname and v.components.stackable and
                            not v.components.stackable:IsFull() then
                            return k, overflow
                        end
                    end
                end
            end

            return oldGetNextAvailableSlot(self, item)
        end

        local UseItemFromInvTile_old = inst.components.inventory.UseItemFromInvTile
        function inst.components.inventory:UseItemFromInvTile(item)
            if item then
                if item.components.fuel then
                    for k, v in pairs(self.equipslots) do
                        if v.components.fueled and v.components.fueled:CanAcceptFuelItem(item) and
                            v.components.fueled.maxfuel - v.components.fueled.currentfuel >
                            item.components.fuel.fuelvalue then
                            self.inst.components.locomotor:PushAction(
                                GLOBAL.BufferedAction(inst, v, GLOBAL.ACTIONS.ADDFUEL, item), true)
                            return
                        end
                    end
                elseif item.components.sewing then
                    for k, v in pairs(self.equipslots) do
                        if v:HasTag("needssewing") and v.components.fueled.maxfuel - v.components.fueled.currentfuel >
                            item.components.sewing.repair_value then
                            self.inst.components.locomotor:PushAction(
                                GLOBAL.BufferedAction(inst, v, GLOBAL.ACTIONS.SEW, item), true)
                            return
                        end
                    end
                end
            end
            return UseItemFromInvTile_old(self, item)
        end
    end)
end
if GLOBAL.TheNet:GetIsClient() or not GLOBAL.TheNet:GetServerIsDedicated() then
    local BIND_KEY = GetModConfigData("key_toggle_bind") or 288
    local alert_stack_threshold = GetModConfigData("alert_stack_threshold") or 0
    local disable_raw_inventory_hotkey = GetModConfigData("disable_raw_inventory_hotkey") or 0

    local Image = require("widgets/image")
    local TEMPLATES = require "widgets/redux/templates"
    local PopupDialogScreen = require "screens/redux/popupdialog"
    local ProfileSwitchPanel = require("screens/ProfileSwitchPanel")

    local showBindKeyScreen = function(current_key, callback)
        local default_text = string.format(GLOBAL.STRINGS.UI.OPTIONS.CURRENT_CONTROL_TEXT, GLOBAL.STRINGS.UI
                                               .CONTROLSSCREEN.INPUTS[1][current_key] or
                                               GLOBAL.STRINGS.UI.CONTROLSSCREEN.INPUTS[9][2])
        local body_text = GLOBAL.STRINGS.UI.CONTROLSSCREEN.CONTROL_SELECT .. "\n\n" .. default_text

        local buttons = {
            {
                text = GLOBAL.STRINGS.UI.CONTROLSSCREEN.UNBIND,
                cb = function()
                    callback(nil)
                    GLOBAL.TheFrontEnd:PopScreen()
                end,
            },
            {
                text = GLOBAL.STRINGS.UI.CONTROLSSCREEN.CANCEL,
                cb = function()
                    GLOBAL.TheFrontEnd:PopScreen()
                end,
            },
        }

        local popup = PopupDialogScreen(GLOBAL.STRINGS.UI.CONTROLSSCREEN.RESETTITLE, body_text, buttons)

        popup.OnRawKey = function(_, key, down)
            if not down and GLOBAL.STRINGS.UI.CONTROLSSCREEN.INPUTS[1][key] then
                callback(key)
                GLOBAL.TheFrontEnd:PopScreen()
                GLOBAL.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
                return true
            end
        end
        for _, item in ipairs(popup.dialog.actions.items) do
            item:ClearFocusDirs()
        end
        popup.default_focus = nil
        GLOBAL.TheFrontEnd:PushScreen(popup)
    end

    local filepath = "mod_config_data/improved_inventory_helper_config"
    local improved_inventory_helper_shown = false
    local global_config = {
        data = {
            -- [1] = {
            --     name="",
            --     desc="",
            --     config={}
            -- },
            -- [2] = ...
        },
        profile = 1,
    }
    GLOBAL.TheSim:GetPersistentString(filepath, function(load_success, str)
        if load_success == true then
            local success, savedata = GLOBAL.RunInSandboxSafe(str)
            if success and string.len(str) > 0 then
                print("[IMPROVED INVENTORY] Loaded saved data successfully")
                global_config = savedata
            else
                print("[IMPROVED INVENTORY] Failed to load saved data")
            end
        else
            print("[IMPROVED INVENTORY] Can not find " .. filepath)
        end
    end)

    AddClassPostConstruct("widgets/inventorybar", function(self)
        self.improved_inventory_helper_bar = {}

        local function loadLocalConfig()
            if global_config.data[global_config.profile] then
                self.owner.replica.improved_inventory_helper:UpdateAllConfig(
                    global_config.data[global_config.profile].config)
                self.owner.replica.improved_inventory_helper:UpdateWithRPC()
            end
        end

        if GLOBAL.TheNet:GetServerGameMode() == "quagmire" then
            return
        end

        self:AddEquipSlot(GLOBAL.EQUIPSLOTS.BACKPACK, "images/equip_slot_backpack.xml", "equip_slot_backpack.tex")
        self:AddEquipSlot(GLOBAL.EQUIPSLOTS.CLOTHING, "images/equip_slot_cloth.xml", "equip_slot_cloth.tex")
        self:AddEquipSlot(GLOBAL.EQUIPSLOTS.NECK, "images/equip_slot_neck.xml", "equip_slot_neck.tex")

        local slot_width = 68
        local slot_inter_width = 12
        local group_inter_width = 28

        local Rebuild_old = self.Rebuild
        function self:Rebuild()
            Rebuild_old(self)

            for i, helper in ipairs(self.improved_inventory_helper_bar) do
                helper.bg:Kill()
                helper.bd:Kill()
                helper.ctl:Kill()
            end

            local do_self_inspect = not (self.controller_build or GLOBAL.GetGameModeProperty("no_avatar_popup"))
            local num_slots = self.owner.replica.inventory:GetNumSlots()
            local num_group_inter = math.ceil(num_slots / 5)
            local num_equips = #self.equipslotinfo
            local num_buttons = do_self_inspect and 1 or 0

            local total_w_real = (num_slots + num_equips + num_buttons) * slot_width +
                                     (num_slots + num_equips + num_buttons - num_group_inter - num_buttons - 1) *
                                     slot_inter_width + (num_group_inter + num_buttons) * group_inter_width

            local scale = 1.22 * total_w_real / 1572
            self.bg:SetScale(scale, 1, 1)
            self.bgcover:SetScale(scale, 1, 1)

            for i, inv_slot in ipairs(self.inv) do
                self.improved_inventory_helper_bar[i] = {}
                self.improved_inventory_helper_bar[i].bg = inv_slot:AddChild(Image())

                if inv_slot.tile ~= nil then
                    inv_slot.tile:MoveToFront()
                end
                if inv_slot.label ~= nil then
                    inv_slot.label:MoveToFront()
                end
                if inv_slot.readonlyvisual ~= nil then
                    inv_slot.readonlyvisual:MoveToFront()
                end

                self.improved_inventory_helper_bar[i].bd = inv_slot:AddChild(
                                                               Image("images/equip_slot_error_bd.xml",
                                                                     "equip_slot_error_bd.tex"))
                self.improved_inventory_helper_bar[i].bd:Hide()

                local inv_slot_position = inv_slot:GetPosition()

                local key_btn = TEMPLATES.StandardButton(function()
                    if improved_inventory_helper_shown then
                        showBindKeyScreen(self.owner.replica.improved_inventory_helper.config.key_slot_map[i],
                                          function(new_key)
                            self.owner.replica.improved_inventory_helper:BindKey(i, new_key)
                        end)
                    end
                end, nil, {70, 70})
                self.improved_inventory_helper_bar[i].key = self.toprow:AddChild(key_btn)
                self.improved_inventory_helper_bar[i].key:SetPosition(inv_slot_position.x, inv_slot_position.y + 90, 0)
                if not improved_inventory_helper_shown then
                    self.improved_inventory_helper_bar[i].key:Hide()
                end

                local ctl_btn = TEMPLATES.StandardButton(function()
                    self.owner.replica.improved_inventory_helper:BindLocal(i)
                end, nil, {70, 70}, {"images/unlocked.xml", "unlocked.tex"})
                self.improved_inventory_helper_bar[i].ctl = self.toprow:AddChild(ctl_btn)
                self.improved_inventory_helper_bar[i].ctl:SetPosition(inv_slot_position.x, inv_slot_position.y + 160, 0)
                if not improved_inventory_helper_shown then
                    self.improved_inventory_helper_bar[i].ctl:Hide()
                end
            end

            local base_position = self.inv[1]:GetPosition()
            local switch_btn = TEMPLATES.StandardButton(function()
                GLOBAL.TheFrontEnd:PushScreen(ProfileSwitchPanel(global_config, function(data, new_key)
                    if data and new_key then
                        global_config.data = data
                        global_config.profile = new_key
                        GLOBAL.SavePersistentString(filepath, GLOBAL.DataDumper(global_config, nil, true), false)
                        loadLocalConfig()
                    end
                end))
            end, nil, {80, 80}, {"images/setting.xml", "setting.tex"})
            self.improved_inventory_helper_profile_switch = self.toprow:AddChild(switch_btn)
            self.improved_inventory_helper_profile_switch:SetPosition(base_position.x - 120, base_position.y, 0)
            self.improved_inventory_helper_profile_switch:Hide()
        end

        local OnUpdate_old = self.OnUpdate
        function self:OnUpdate(dt)
            OnUpdate_old(self, dt)
            for i = 1, #self.inv do
                local current_item = self.owner.replica.inventory:GetItemInSlot(i)
                local save_prefab = self.owner.replica.improved_inventory_helper:GetSlotItem(i)
                if save_prefab and
                    (not current_item or save_prefab ~= current_item.prefab or (current_item.replica.stackable and
                        (current_item.replica.stackable:StackSize() / current_item.replica.stackable:MaxSize() <
                            alert_stack_threshold))) then
                    self.improved_inventory_helper_bar[i].bd:Show()
                else
                    self.improved_inventory_helper_bar[i].bd:Hide()
                end
            end
        end

        self.owner:DoTaskInTime(0, function()
            loadLocalConfig()
            self.owner:ListenForEvent("improved_inventory_helper_config_updated", function()
                for i = 1, #self.inv do
                    local atlas, image = self.owner.replica.improved_inventory_helper:GetSlotConfig(i)
                    if atlas and image then
                        self.improved_inventory_helper_bar[i].bg:SetTexture(atlas, image)
                        self.improved_inventory_helper_bar[i].bg:SetTint(0.95, 0.95, 0.95, 0.35)
                        self.improved_inventory_helper_bar[i].bg:Show()
                        self.improved_inventory_helper_bar[i].ctl.icon:SetTexture("images/locked.xml", "locked.tex")
                    else
                        self.improved_inventory_helper_bar[i].bg:Hide()
                        self.improved_inventory_helper_bar[i].ctl.icon:SetTexture("images/unlocked.xml", "unlocked.tex")
                    end
                    local key = self.owner.replica.improved_inventory_helper:GetKeyBind(i)
                    if key then
                        self.improved_inventory_helper_bar[i].key:SetText(
                            GLOBAL.STRINGS.UI.CONTROLSSCREEN.INPUTS[1][key])
                        self.improved_inventory_helper_bar[i].key:Show()
                    else
                        self.improved_inventory_helper_bar[i].key:SetText(nil)
                        if not improved_inventory_helper_shown then
                            self.improved_inventory_helper_bar[i].key:Hide()
                        end
                    end
                end
                global_config.data[global_config.profile] = global_config.data[global_config.profile] or {
                    name = GLOBAL.STRINGS.UI.COLLECTIONSCREEN.NEW,
                    desc = GLOBAL.STRINGS.UI.COLLECTIONSCREEN.NEW .. "  " .. (#global_config.data + 1),
                    config = {},
                }
                global_config.data[global_config.profile].config = self.owner.replica.improved_inventory_helper.config
                GLOBAL.dumptable(global_config)
                print(("[IMPROVED INVENTORY] Saving config to profile %d"):format(global_config.profile))
                GLOBAL.SavePersistentString(filepath, GLOBAL.DataDumper(global_config, nil, true), false)
            end)
        end)
    end)

    GLOBAL.TheInput:AddKeyHandler(function(key, down)
        if GLOBAL.ThePlayer and down and GLOBAL.TheFrontEnd:GetActiveScreen() and
            GLOBAL.TheFrontEnd:GetActiveScreen().name == "HUD" then
            if key == BIND_KEY then
                if improved_inventory_helper_shown then
                    for i, helper in ipairs(GLOBAL.ThePlayer.HUD.controls.inv.improved_inventory_helper_bar) do
                        helper.ctl:Hide()
                        if not GLOBAL.ThePlayer.replica.improved_inventory_helper:GetKeyBind(i) then
                            helper.key:Hide()
                        end
                    end
                    GLOBAL.ThePlayer.HUD.controls.inv.improved_inventory_helper_profile_switch:Hide()
                    improved_inventory_helper_shown = false
                    GLOBAL.ThePlayer.replica.improved_inventory_helper:UpdateWithRPC()
                else
                    for _, helper in ipairs(GLOBAL.ThePlayer.HUD.controls.inv.improved_inventory_helper_bar) do
                        helper.ctl:Show()
                        helper.key:Show()
                    end
                    GLOBAL.ThePlayer.HUD.controls.inv.improved_inventory_helper_profile_switch:Show()
                    improved_inventory_helper_shown = true
                end
            else
                local inv = GLOBAL.ThePlayer.HUD.controls.inv
                for i = 1, #inv.inv do
                    if key == inv.owner.replica.improved_inventory_helper:GetKeyBind(i) then
                        inv.owner.replica.improved_inventory_helper:TriggerSlotAction(i)
                        break
                    end
                end
            end
        end
    end)

    if disable_raw_inventory_hotkey then
        AddClassPostConstruct("screens/playerhud", function(self)
            local OnControl_old = self.OnControl
            function self:OnControl(control, down)
                if (control >= GLOBAL.CONTROL_INV_1 and control <= GLOBAL.CONTROL_INV_10) or
                    (control >= GLOBAL.CONTROL_INV_11 and control <= GLOBAL.CONTROL_INV_15) then
                    return true
                else
                    return OnControl_old(self, control, down)
                end
            end
        end)
    end
end
