name = "秘密基地开服自用"

description = [[服务器自用]]

author = "剑锋不再温柔"
version = "0.0.1"
version_compatible = "0.0.1"
forumthread = ""

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = true
client_only_mod = false
server_only_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

local worldconfig_example = {
    ["1"] = {
        name = "大观楼"
        -- invisible = true --设置此属性则该世界不在UI中现实
    },
    ["2"] = {
        name = "怡红院",
        category = "建设"
    },
    ["3"] = {
        name = "蘅芜苑",
        category = "建设"
    },
    ["4"] = {
        name = "潇湘馆",
        note = "宝鼎茶闲烟尚绿，幽窗棋罢指犹凉",
        category = "建设"
    },
    ["5"] = {
        name = "沁芳亭",
        category = "其他",
        is_cave = true,
        galleryful = 12, --人数上限
        extra = true --不作为分流目的地
    },
    ["51"] = {
        name = "栊翠庵",
        category = "其他",
        is_cave = true,
        galleryful = 12, --人数上限
        extra = true --不作为分流目的地
    }
}
--]?]

configuration_options = {
    -- {
    --     name = "language",
    --     label = "语言",
    --     hover = "支持繁中、简中和英文",
    --     --默认会尝试通过时区及中文语言Mod检测，建议直接设置需要的语言
    --     options = {
    --         {description = "自动", data = "auto"},
    --         {description = "English", data = "en"},
    --         {description = "繁體", data = "cht"},
    --         {description = "简体", data = "chs"}
    --     },
    --     default = "chs"
    -- },
    --世界配置
    {
        name = "world_config",
        label = "世界配置",
        hover = "可以详细配置每个世界的具体信息，如名字、人数限制、说明等等",
        ----注意：此table的键为世界ID，键必须是字符串形式
        options = {
            {description = "示例", data = worldconfig_example, hover = "具体支持的属性或许写在 README.md 中"},
            {description = "空", data = {}, hover = "emmm...设置为空表也不是不可以"}
        },
        default = worldconfig_example
    },
    --default galleryful
    {
        name = "default_galleryful",
        label = "默认人数上限",
        hover = "针对每个世界的默认人数上限",
        --注意：这个设置并不是强力的，可能会出现人数超出限制的情况
        options = {
            {description = "不限", data = 0, hover = "设为0或nil表示不限制最大人数"},
            {description = "6人", data = 6, hover = "设定默认的人数限制为6人"}
        },
        default = 0
    },
    --自动分流
    {
        name = "auto_balancing",
        label = "自动分流",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = false
    },
    --no bat
    {
        name = "no_bat",
        label = "防止洞口生成蝙蝠",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = true
    },
    --提示世界名称
    {
        name = "world_prompt",
        label = "提示世界名称",
        hover = "当进入某个世界，玩家说出当前所处世界名称",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = false
    },
    --say dest
    {
        name = "say_dest",
        label = "说出目的地",
        hover = "玩家在跳世界之前，将说出目的地，以提示其它玩家",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = true
    },
    {
        name = "migration_postern",
        label = "绚丽之门作为洞口",
        hover = "对幽灵不起作用",
        --有较小几率造成洞口ID的混乱
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = false
    },
    --忽略落水洞
    {
        name = "ignore_sinkholes",
        label = "忽略落水洞",
        hover = "不在落水洞上启用选择器",
        --若您只想在朋友传送门或绚丽之门上打开世界选择器，则启用此选项
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = false
    },
    --UI控件
    {
        name = "open_button",
        label = "黑洞按钮",
        hover = "在左上角显示黑洞按钮",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = true
    },
    {
        name = "migrator_required",
        label = "限制穿越",
        hover = "严格限制仅在传送口附近才可穿越世界",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = false
    },
    {
        name = "force_population",
        label = "防止人数超限",
        hover = "!!!实验特性，谨慎开启，后果自负!!!\n玩家尝试通过下线再上线的方式突破人数限制时，强制将玩家传至其他可作分流目的地的世界。\n当可选的其他世界没有空位时，依然可能超限。",
        options = {
            {description = "开启", data = true},
            {description = "上限10人", data = 10},
            {description = "上限12人", data = 12},
            {description = "上限15人", data = 15},
            {description = "关闭", data = false}
        },
        default = false
    },
    {
        name = "name_button",
        label = "名称显示",
        hover = "在左上角显示世界名称",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = true
    },
    {
        name = "always_show_ui",
        label = "总是显示UI",
        hover = "不检查世界数量，启用后不会在只有一个从世界时直接传送\n主要用于测试目的",
        options = {
            {description = "开启", data = true},
            {description = "关闭", data = false}
        },
        default = false
    },
    {
        name = "gift_toasts_offset",
        label = "礼物按钮偏移",
        hover = "礼物提示按钮的横向位置偏移",
        options = {
            {description = "右移100", data = 100},
            {description = "右移200", data = 200},
            {description = "右移300", data = 300},
            {description = "右移400", data = 400},
            {description = "右移500", data = 500},
            {description = "右移600", data = 600},
            {description = "关闭", data = 0}
        },
        default = 100
    }
}

