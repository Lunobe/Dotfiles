local obs = obslua

local audio_file = ""
local use_flatpak_host = false
local player = "pw-play" -- "pw-play" | "paplay" | "ffplay"

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local function run(cmd)
    obs.script_log(obs.LOG_INFO, "Running: " .. cmd)
    local ok, reason, code = os.execute(cmd)
    obs.script_log(obs.LOG_INFO, string.format("os.execute => ok=%s reason=%s code=%s",
        tostring(ok), tostring(reason), tostring(code)))
end

local function play_sound()
    if audio_file == "" then
        obs.script_log(obs.LOG_WARNING, "Audio file path is empty")
        return
    end

    if not file_exists(audio_file) then
        obs.script_log(obs.LOG_ERROR, "Audio file NOT FOUND: " .. audio_file)
        return
    end

    local cmd = ""
    if player == "pw-play" then
        cmd = string.format('pw-play "%s" >/dev/null 2>&1 &', audio_file)
    elseif player == "paplay" then
        cmd = string.format('paplay "%s" >/dev/null 2>&1 &', audio_file)
    else -- ffplay
        cmd = string.format('ffplay -nodisp -autoexit "%s" >/dev/null 2>&1 &', audio_file)
    end

    if use_flatpak_host then
        cmd = 'flatpak-spawn --host sh -lc ' .. string.format("%q", cmd)
    end

    run(cmd)
end

local function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        obs.script_log(obs.LOG_INFO, "Replay buffer saved event fired")
        play_sound()
    end
end

function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_path(props, "audio_file", "Audio file",
        obs.OBS_PATH_FILE, "WAV (*.wav);;All Files (*.*)", nil)

    obs.obs_properties_add_list(props, "player", "Player",
        obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(obs.obs_properties_get(props, "player"), "pw-play (PipeWire)", "pw-play")
    obs.obs_property_list_add_string(obs.obs_properties_get(props, "player"), "paplay (PulseAudio)", "paplay")
    obs.obs_property_list_add_string(obs.obs_properties_get(props, "player"), "ffplay (FFmpeg)", "ffplay")

    obs.obs_properties_add_bool(props, "use_flatpak_host", "OBS is Flatpak (run player via host)")

    return props
end

function script_update(settings)
    audio_file = obs.obs_data_get_string(settings, "audio_file")
    player = obs.obs_data_get_string(settings, "player")
    use_flatpak_host = obs.obs_data_get_bool(settings, "use_flatpak_host")

    obs.script_log(obs.LOG_INFO, "Updated settings: file=" .. tostring(audio_file) ..
        " player=" .. tostring(player) ..
        " flatpak_host=" .. tostring(use_flatpak_host))
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "player", "pw-play")
    obs.obs_data_set_default_bool(settings, "use_flatpak_host", false)
end

function script_load(settings)
    obs.obs_frontend_add_event_callback(on_event)
    obs.script_log(obs.LOG_INFO, "Beep script loaded")
end
