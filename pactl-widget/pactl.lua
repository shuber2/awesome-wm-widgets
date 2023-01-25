local spawn = require("awful.spawn")
local utils = require("awesome-wm-widgets.pactl-widget.utils")

local pactl = {}


function pactl.volume_increase(device, step)
    spawn('pactl set-sink-volume ' .. device .. ' +' .. step .. '%', false)
end

function pactl.volume_decrease(device, step)
    spawn('pactl set-sink-volume ' .. device .. ' -' .. step .. '%', false)
end

function pactl.mute_toggle(device)
    spawn('pactl set-sink-mute ' .. device .. ' toggle', false)
end

function pactl.get_default_sink()
    local line = utils.popen_and_return('pactl info'):match('Default Sink: [^\n]*')
    if line == nil then
        return "none"
    end

    local t = utils.split(line, ':')
    return utils.trim(t[2])
end

function pactl.get_volume(device)
    if device == '@DEFAULT_SINK@' then
        device = pactl.get_default_sink()
    end

    local volsum, volcnt = 0, 0
    local matched_sink = false
    for line in utils.popen_and_return('pactl list sinks'):gmatch('([^\r\n]*)[\r\n]') do
        local linetrim = utils.trim(line)

        if linetrim == "Name: " .. device then
            matched_sink = true
        end

        if matched_sink and linetrim:match("^Volume:") then

            for vol in string.gmatch(linetrim, "(%d?%d?%d)%%") do
                vol = tonumber(vol)
                if vol ~= nil then
                    volsum = volsum + vol
                    volcnt = volcnt + 1
                end
            end
            break
        end
    end

    if volcnt == 0 then
        return nil
    end

    return volsum / volcnt
end

function pactl.get_mute(device)

    if device == '@DEFAULT_SINK@' then
        device = pactl.get_default_sink()
    end

    local volsum, volcnt = 0, 0
    local matched_sink = false
    for line in utils.popen_and_return('pactl list sinks'):gmatch('([^\r\n]*)[\r\n]') do
        local linetrim = utils.trim(line)

        if linetrim == "Name: " .. device then
            matched_sink = true
        end

        if matched_sink and linetrim == "Mute: yes" then
            return true
        end
    end

    return false
end

function pactl.get_sinks_and_sources()
    local default_sink = utils.trim(utils.popen_and_return('pactl get-default-sink'))
    local default_source = utils.trim(utils.popen_and_return('pactl get-default-source'))

    local sinks = {}
    local sources = {}

    local device
    local ports
    local key
    local value
    local in_section

    for line in utils.popen_and_return('pactl list'):gmatch('[^\r\n]*') do

        if string.match(line, '^%a+ #') then
            in_section = nil
        end

        local is_sink_line = string.match(line, '^Sink #')
        local is_source_line = string.match(line, '^Source #')

        if is_sink_line or is_source_line then
            in_section = "main"

            device = {
                id = line:match('#(%d+)'),
                is_default = false
            }
            if is_sink_line then
                table.insert(sinks, device)
            else
                table.insert(sources, device)
            end
        end

        -- Found a new subsection
        if in_section ~= nil and string.match(line, '^\t%a+:$') then
            in_section = utils.trim(line):lower()
            in_section = string.sub(in_section, 1, #in_section-1)

            if in_section == 'ports' then
                ports = {}
                device['ports'] = ports
            end
        end

        -- Found a key-value pair
        if string.match(line, "^\t*[^\t]+: ") then
            local t = utils.split(line, ':')
            key = utils.trim(t[1]):lower():gsub(' ', '_')
            value = utils.trim(t[2])
        end

        -- Key value pair on 1st level
        if in_section ~= nil and string.match(line, "^\t[^\t]+: ") then
            device[key] = value

            if key == "name" and (value == default_sink or value == default_source) then
                device['is_default'] = true
            end
        end

        -- Key value pair in ports section
        if in_section == "ports" and string.match(line, "^\t\t[^\t]+: ") then
            ports[key] = value
        end
    end

    return sinks, sources
end

function pactl.set_default(type, name)
    spawn('pactl set-default-' .. type .. ' "' .. name .. '"', false)
end


return pactl
