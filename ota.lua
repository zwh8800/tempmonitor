require('common')
local version = require('version');

local API_COMMITS = 'https://api.github.com/repos/zwh8800/tempmonitor/commits?page=1&per_page=1'

local module = {}

local function parse_json_date(json_date)
    local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
    local year, month, day, hour, minute, 
        seconds, offsetsign, offsethour, offsetmin = json_date:match(pattern)
    local timestamp = os.time{year = year, month = month, 
        day = day, hour = hour, min = minute, sec = seconds}
    local offset = 0
    if offsetsign ~= 'Z' then
      offset = tonumber(offsethour) * 60 + tonumber(offsetmin)
      if xoffset == "-" then offset = offset * -1 end
    end
    
    return timestamp + offset
end

local function get_latest_commit() 
    local code, data = await(http.get)(API_COMMITS, nil)
    if code != 200 then
        print('error when call API_COMMITS status: ' .. code .. ' data: ' .. data)
        return nil
    end
    local commits = cjson.decode(data)
    if commits == nil or #commits == 0 then
        return nil
    end
    return commit[1]
end

local function get_commit_tree(url)
    local code, data = await(http.get)(url, nil)
    if code != 200 then
        print('error when call API_TREE ' .. url, 'status: ' .. code, 'data: ' .. data)
        return nil
    end
    return cjson.decode(data)
end

local function get_file_content(url)
    local code, data = await(http.get)(url, nil)
    if code != 200 then
        print('error when call API_BLOBS ' .. url, 'status: ' .. code, 'data: ' .. data)
        return nil
    end
    local blob = cjson.decode(data)
    if blob.encoding ~= 'base64' then
        return nil
    end
    return encoder.fromBase64(blob.content)
end

local function do_update(tree)
    local file_to_delete = file.list()
    for _, tree_file in ipairs(tree) do
    repeat  -- fucking continue
        file_to_delete[tree_file.path] = nil
        print('downloading file: ' .. tree_file.path)
        local file_content = get_file_content(tree_file.url)
        if file_content == nil then
            print('get file content error: ' .. tree_file.url)
            break   --continue
        end
        print('writing file: ' .. tree_file.path)
        local f = file.open(tree_file.path, 'w')
        f:write(file_content)
        f:close()
        print('write file ok: ' .. tree_file.path)
    until true
    end
    for filename in pairs(file_to_delete) do
        print('remove file: ' .. filename)
        file.remove(filename)
    end
end

local function check_and_update() 
    local commit = get_latest_commit()
    if commit == nil then
        return
    end

    local sha = commit.sha
    local commit_date = commit.commit.author.date
    local commit_timestamp = parse_json_date(commit_date)
    if commit_timestamp <= version then
        return
    end

    local tree = get_commit_tree(url)
    print('updating from ' .. sha)

    do_update(tree.tree)
    print('restart...')
    node.restart()
end

local is_updating = false
function module.update()
    if is_updating then
        return
    end
    coroutine.wrap(function() 
        is_updating = true
        local ok, err = pcall(check_and_update)
        if not ok then
            print('error occurs when check_and_update: ' .. err)
        end
        is_updating = false
    end)()
end

return module
