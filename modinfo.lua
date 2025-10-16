name = "Improved Inventory"
description = [[
主要功能：
1. 增加装备栏到六格，除护符类外，都采用了非白名单方式，兼容性较好。
2. 允许绑定物品栏（不包括背包部分）到固定的一种物品，并且在放入其他物品或物品不足时用红框提示，避免遗漏关键物品
3. 可以定制某个物品栏的快捷按键，同时快捷按键可以对已装备物品进行缝补或补充燃料
4. 2、3项设置均保存在本地，并且可以在多个预设间切换，适应不同的场景需求

Main functions:
1. The equipment bar has been expanded to six slots. Except for talismans, all items use a non-whitelist approach for better compatibility.
2. Inventory (excluding backpack) can be bound to a specific item, red box alerts for wrong items or low quantity to avoid missing key items.
3. You can customize the shortcut keys for a specific item slot, and these shortcut keys can be used to mend equipped items or refuel
4. Settings for 2 and 3 are saved locally and can be switched between presets for different scenarios.
]]
forumthread = ""
author = "Fengying"

version = "1.0.2"
version_compatible = "1.0.0"

api_version = 10
dont_starve_compatible = false
reign_of_giants_compatible = false
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
server_filter_tags = {}

priority = 0

icon_atlas = "preview.xml"
icon = "preview.tex"

configuration_options = {
    {
        name = "key_toggle_bind",
        label = "设置热键\nToggle Setting View",
        options = {
            {description = "F1", data = 282},
            {description = "F2", data = 283},
            {description = "F3", data = 284},
            {description = "F4", data = 285},
            {description = "F5", data = 286},
            {description = "F6", data = 287},
            {description = "F7", data = 288},
            {description = "F8", data = 289},
            {description = "F9", data = 290},
            {description = "F10", data = 291},
            {description = "F11", data = 292},
            {description = "F12", data = 293},
        },
        default = 288,
    },
    {
        name = "alert_stack_threshold",
        label = "物品少于多少的时候报警？\nRaise alert when stack size is below",
        options = {
            {description = "100%", data = 1},
            {description = "75%", data = .75},
            {description = "50%", data = .5},
            {description = "25%", data = .25},
            {description = "Never", data = 0},
        },
        default = 0,
    },
    {
        name = "disable_raw_inventory_hotkey",
        label = "禁用原版物品栏热键\nDisable raw inventory hotkey",
        options = {{description = "no", data = false}, {description = "yes", data = true}},
        default = true,
    },
}
