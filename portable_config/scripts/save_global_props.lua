--[[

SOURCE_ https://github.com/zenwarr/mpv-config/blob/master/scripts/remember-props.lua
COMMIT_ 20220811 03cfc0e39682a73d9d24a6e01a3c02716a019d1d

记录全局的属性变化，支持在下次程序启动时恢复，其对应数据保存在对应文件 saved-props.json
（选项 --save-position-on-quit 保存的是基于具体文件的属性，不要与 --watch-later-options 保存的属性相冲突）

示例在 input.conf 中写入（清除已记录的数据）：
CTRL+r script-message-to save_global_props clean_data

]]

local mp = require("mp")
local options = require("mp.options")
local utils = require("mp.utils")

local script_options = {
	save_mode = 1,                     -- <0|1|2> 保存属性的时机。不保存/正常退出前/基于属性变化
	props     = "volume,mute,speed",   -- 自定义要记录的属性
	cache_dir = "~~/"                  -- 缓存文件的路径
}
options.read_options(script_options)

if script_options.save_mode == 0 then
	mp.msg.info("已禁用保存全局属性的功能")
	return
end

local function split(inputstr, sep)
	local result = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(result, str)
	end
	return result
end

script_options.props = split(script_options.props, ",")

local cleaned = false
local data_file_path = (mp.command_native({'expand-path', script_options.cache_dir .. "saved-props.json"}))

local function read_data_file()
	local json_file = io.open(data_file_path, 'a+')
	local result = utils.parse_json(json_file:read("*all"))
	if result == nil then
		result = {}
	end
	json_file:close()
	return result
end

local saved_data = read_data_file()

local function save_data_file()
	if cleaned then
		mp.msg.verbose("因清理属性记录而中止保存功能")
		return
	end
	local file = io.open(data_file_path, 'w+')
	if file == nil then
		return
	end
	local content, ret = utils.format_json(saved_data)
	if ret ~= error and content ~= nil then
		file:write(content)
	end
	file:close()
end

local function clean_data_file()
	local file = io.open(data_file_path, 'w+')
	if file == nil then
		return
	end
	local content = ''
	file:write(content)
	file:close()
	cleaned = true
	mp.osd_message("已清理记录的属性\n建议重启mpv", 2)
end

local function init()
	for _, prop_name in ipairs(script_options.props) do
		local saved_value = saved_data[prop_name]
		if saved_value ~= nil then
			mp.set_property_native(prop_name, saved_value)
		end
		if script_options.save_mode == 2 then
			mp.observe_property(prop_name, "native", function(_, prop_value)
				saved_data[prop_name] = mp.get_property_native(prop_name)
				save_data_file()
			end)
		end
	end
end

init()

if script_options.save_mode == 1 then
	mp.register_event("shutdown", function()
		for _, prop_name in ipairs(script_options.props) do
			saved_data[prop_name] = mp.get_property_native(prop_name)
			save_data_file()
		end
	end)
end

mp.register_script_message("clean_data", clean_data_file)
