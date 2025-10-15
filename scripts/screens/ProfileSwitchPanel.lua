local Widget = require "widgets/widget"
local Screen = require "widgets/screen"
local TextButton = require "widgets/textbutton"
local TEMPLATES = require "widgets/redux/templates"

local ITEM_WIDTH, ITEM_HEIGHT = 300, 80

local ProfileSwitchPanel = Class(Screen, function(self, global_config, callback)
    Screen._ctor(self, "ProfileSwitchPanel")
    self.apply_cb = callback
    self.data = global_config.data or {}
    self.current = global_config.profile or 1

    self.root = self:AddChild(Widget("root"))
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)

    self.list_host = self.root:AddChild(TEMPLATES.RectangleWindow(250, 430))
    self.list_host:SetPosition(0, 0)

    self.btn_new = self.list_host:AddChild(TEMPLATES.StandardButton(function()
        table.insert(self.data, {
            name = STRINGS.UI.COLLECTIONSCREEN.NEW,
            desc = STRINGS.UI.COLLECTIONSCREEN.NEW .. "  " .. (#self.data + 1),
            config = {item_slot_map = {}, item_image = {}, key_slot_map = {}},
        })
        self:RefreshList()
    end, nil, {ITEM_WIDTH, 40}))
    self.btn_new:SetText("+")
    self.btn_new:SetPosition(0, -190, 0)

    self:RefreshList()
end)

function ProfileSwitchPanel:Close()
    TheFrontEnd:PopScreen(self)
    self.apply_cb(self.data, self.current)
end

function ProfileSwitchPanel:RefreshList()
    local function listItemCtor(_, index)
        local widget = Widget("widget-" .. index)
        widget:SetOnGainFocus(function()
            if self.scroll_lists then
                self.scroll_lists:OnWidgetFocus(widget)
            end
        end)
        widget.record_item = widget:AddChild(self:CreateListItem())
        local record = widget.record_item
        widget.focus_forward = record
        return widget
    end

    local function RenderListItem(_, widget, data, idx)
        if not data then
            widget.focus_forward = nil
            widget.record_item:Hide()
            return
        end
        widget.focus_forward = widget.record_item
        widget.record_item.SetInfo(data, idx)
        widget.record_item:Show()
    end

    if self.scroll_lists then
        self.scroll_lists:Kill()
    end

    self.scroll_lists = self.list_host:AddChild(TEMPLATES.ScrollingGrid(self.data, {
        context = {},
        widget_width = ITEM_WIDTH,
        widget_height = ITEM_HEIGHT,
        num_visible_rows = 4,
        num_columns = 1,
        item_ctor_fn = listItemCtor,
        apply_fn = RenderListItem,
        scrollbar_offset = 10,
        scrollbar_height_offset = 0,
        peek_height = 40,
        allow_bottom_empty_row = true,
    }))
    self.scroll_lists:SetPosition(0, 40)
end

function ProfileSwitchPanel:CreateListItem()
    local record = Widget("improved-inventory-record-item")

    record.bg = record:AddChild(TEMPLATES.ListItemBackground(ITEM_WIDTH, ITEM_HEIGHT, function()
    end))
    record.bg.move_on_click = true

    record.name = record:AddChild(TEMPLATES.StandardSingleLineTextEntry("", ITEM_WIDTH - 20, 20, BODYTEXTFONT, 24,
                                                                        "Title"))
    record.name.textbox:SetTextLengthLimit(15)
    record.name:SetPosition(0, 20, 0)

    record.desc = record:AddChild(TEMPLATES.StandardSingleLineTextEntry("", ITEM_WIDTH - 20, 20, CHATFONT, 20,
                                                                        "Description"))
    record.desc.textbox:SetTextLengthLimit(80)
    record.desc:SetPosition(0, 0, 0)

    record.apply = record:AddChild(TextButton())
    record.apply:SetFont(CHATFONT)
    record.apply:SetTextSize(20)
    record.apply:SetText(STRINGS.UI.OPTIONS.APPLY)
    record.apply:SetPosition(70, -25, 0)
    record.apply:SetTextFocusColour({1, 1, 1, 1})
    record.apply:SetTextColour({0, 1, 0, 1})

    record.delete = record:AddChild(TextButton())
    record.delete:SetFont(CHATFONT)
    record.delete:SetTextSize(20)
    record.delete:SetText(STRINGS.UI.MAINSCREEN.DELETE)
    record.delete:SetPosition(100, -25, 0)
    record.delete:SetTextFocusColour({1, 1, 1, 1})
    record.delete:SetTextColour({1, 0, 0, 1})

    record.SetInfo = function(data, idx)
        record.name.textbox:SetString(data.name)
        record.name.textbox.OnTextInputted = function()
            self.data[idx].name = record.name.textbox:GetString()
        end

        record.desc.textbox:SetString(data.desc)
        record.desc.textbox.OnTextInputted = function()
            self.data[idx].desc = record.desc.textbox:GetString()
        end

        record.delete:SetOnClick(function()
            if idx == self.current then
                return
            end
            table.remove(self.data, idx)
            if idx < self.current then
                self.current = self.current - 1
            end
            self:RefreshList()
        end)
        record.apply:SetOnClick(function()
            self.current = idx
            self:Close()
        end)
    end

    record.focus_forward = record.bg
    return record
end

function ProfileSwitchPanel:OnControl(control, down)
    if ProfileSwitchPanel._base.OnControl(self, control, down) then
        return true
    end
    if not down and control == CONTROL_CANCEL then
        self:Close()
    end
    return true
end

function ProfileSwitchPanel:OnRawKey(key, down)
    if ProfileSwitchPanel._base.OnRawKey(self, key, down) then
        return true
    end
    return true
end

return ProfileSwitchPanel
