--- @since 26.1.22

local VIDEO_EXTS = {
	mp4 = true,
	mkv = true,
	webm = true,
	mov = true,
	avi = true,
	m4v = true,
	mpeg = true,
	mpg = true,
}

local resolve_targets = ya.sync(function(_, mode)
	local tab = cx.active
	local targets = {}

	local function push(file, url)
		targets[#targets + 1] = {
			url = url,
			name = (file and file.name) or url.name or tostring(url),
			mime = file and file:mime() or nil,
			ext = url.ext,
		}
	end

	if mode == "selected" then
		local by_url = {}
		for i = 1, #tab.current.files do
			local f = tab.current.files[i]
			by_url[tostring(f.url)] = f
		end
		for _, url in pairs(tab.selected) do
			push(by_url[tostring(url)], url)
		end
	else
		local h = tab.current.hovered
		if h then
			push(h, h.url)
		end
	end

	return targets
end)

local function is_video(t)
	if t.mime then
		return t.mime:sub(1, 6) == "video/"
	end
	local ext = t.ext and string.lower(t.ext) or ""
	return VIDEO_EXTS[ext] == true
end

local function notify(level, content)
	ya.notify {
		title = "Actions",
		content = content,
		level = level,
		timeout = 5,
	}
end

local function header_for(mode, targets)
	if mode == "selected" then
		return string.format("Actions for: %d selected", #targets)
	end
	return string.format("Actions for: %s", targets[1] and targets[1].name or "?")
end

local function pick(header, items)
	local lines = {}
	for _, item in ipairs(items) do
		lines[#lines + 1] = string.format("%s\t%s", item.id, item.label)
	end

	local permit = ui.hide()
	local child, err = Command("fzf")
		:arg({
			"--prompt=Action> ",
			"--header=" .. header,
			"--height=100%",
			"--layout=reverse",
			"--border",
			"--delimiter=\t",
			"--with-nth=2",
			"--nth=2",
		})
		:stdin(Command.PIPED)
		:stdout(Command.PIPED)
		:stderr(Command.INHERIT)
		:spawn()

	if not child then
		permit:drop()
		return nil, err
	end

	child:write_all(table.concat(lines, "\n") .. "\n")
	child:flush()

	local output, wait_err = child:wait_with_output()
	permit:drop()

	if not output then
		return nil, wait_err
	end
	if not output.status.success then
		return nil
	end

	local line = output.stdout:match("^[^\r\n]+")
	if not line or line == "" then
		return nil
	end
	return line:match("^([^\t]+)")
end

local function video_targets(targets)
	local videos, skipped = {}, 0
	for _, t in ipairs(targets) do
		if is_video(t) then
			videos[#videos + 1] = t
		else
			skipped = skipped + 1
		end
	end
	return videos, skipped
end

local function out_url(src, suffix)
	local parent = src.url.parent
	local stem = src.url.stem or "out"
	if not parent then
		return nil
	end
	return parent:join(stem .. suffix)
end

local function run_ffmpeg(kind, videos)
	local cmds = {}
	for _, v in ipairs(videos) do
		local src = ya.quote(tostring(v.url))
		local dest_url, vf
		if kind == "gif" then
			dest_url = out_url(v, ".gif")
			vf = string.format(
				"ffmpeg -hide_banner -y -i %s -vf fps=10,scale=480:-1:flags=lanczos %s",
				src,
				ya.quote(tostring(dest_url))
			)
		elseif kind == "mp3" then
			dest_url = out_url(v, ".mp3")
			vf = string.format(
				"ffmpeg -hide_banner -y -i %s -vn -acodec libmp3lame -q:a 2 %s",
				src,
				ya.quote(tostring(dest_url))
			)
		elseif kind == "compress" then
			dest_url = out_url(v, "_compressed.mp4")
			vf = string.format(
				"ffmpeg -hide_banner -y -i %s -c:v libx264 -crf 28 -c:a aac %s",
				src,
				ya.quote(tostring(dest_url))
			)
		end
		if dest_url and vf then
			cmds[#cmds + 1] = vf
		end
	end

	if #cmds == 0 then
		return notify("warn", "Nothing to process")
	end

	ya.emit("shell", {
		table.concat(cmds, " && "),
		block = true,
	})
end

local function ffmpeg_menu(mode, targets)
	local videos, skipped = video_targets(targets)
	if #videos == 0 then
		return notify("warn", "No video files in targets")
	end
	if skipped > 0 then
		notify("info", string.format("Skipping %d non-video file(s)", skipped))
	end

	local header = mode == "selected" and string.format("FFmpeg · %d file(s)", #videos)
		or string.format("FFmpeg · %s", videos[1].name)

	local id, err = pick(header, {
		{ id = "gif", label = "Video → GIF" },
		{ id = "mp3", label = "Extract audio (mp3)" },
		{ id = "compress", label = "Compress (CRF 28)" },
		{ id = "back", label = "← Back" },
	})
	if err then
		return notify("error", tostring(err))
	end
	if not id or id == "back" then
		return "back"
	end

	run_ffmpeg(id, videos)
	return "done"
end

local function root_menu(mode, targets)
	while true do
		local items = {
			{ id = "open", label = "Open with…" },
		}
		local videos = video_targets(targets)
		if #videos > 0 then
			items[#items + 1] = { id = "ffmpeg", label = "FFmpeg…" }
		end

		local id, err = pick(header_for(mode, targets), items)
		if err then
			return notify("error", tostring(err))
		end
		if not id then
			return
		end

		if id == "open" then
			if mode == "hovered" then
				ya.emit("open", { interactive = true, hovered = true })
			else
				ya.emit("open", { interactive = true })
			end
			return
		elseif id == "ffmpeg" then
			local result = ffmpeg_menu(mode, targets)
			if result ~= "back" then
				return
			end
		end
	end
end

return {
	entry = function(_, job)
		local mode = job.args[1] or "hovered"
		if mode ~= "hovered" and mode ~= "selected" then
			return notify("error", "Usage: plugin actions -- hovered|selected")
		end

		ya.emit("escape", { visual = true })

		local targets = resolve_targets(mode)
		if mode == "selected" and #targets == 0 then
			return notify("warn", "Select files first")
		end
		if #targets == 0 then
			return notify("warn", "No file under cursor")
		end

		root_menu(mode, targets)
	end,
}
