-- BEGIN CPDLC PATCH MODULE
-- FANS 1/A CPDLC pages for the stock Zibo/LevelUp datalink CDU (DO-258A texts).
-- Inserted before B738_fmc_disp_capt(); hooked from the LSK handlers
-- (cpdlc_patch_lsk), the display chain (cpdlc_patch_overlay) and dlnk_in_use.

cpdlc_patch_page = 0		-- 0 none, 1 WHEN CAN WE, 2 REPORT, 3 POS REPORT, 4 EMERGENCY, 5 VOICE, 6 COMPOSE VERIFY
cpdlc_patch_return = 0		-- 1 ATC INDEX, 2 CPDLC REPORTS/REQUESTS, 3 DLK ATC MENU
cpdlc_patch_when_climb = "-----"
cpdlc_patch_when_descend = "-----"
cpdlc_patch_when_speed = "---"
cpdlc_patch_when_cruise = "-----"
cpdlc_patch_rep_leaving = "-----"
cpdlc_patch_rep_climbing = "-----"
cpdlc_patch_rep_descending = "-----"
cpdlc_patch_rep_passing = "-----"
cpdlc_patch_rep_assigned_spd = "---"
cpdlc_patch_emerg_type = 0
cpdlc_patch_emerg_descend = "-----"
cpdlc_patch_emerg_divert = "-----"
cpdlc_patch_emerg_offset = "-----"
cpdlc_patch_emerg_fuel = "----"
cpdlc_patch_emerg_souls = "---"
cpdlc_patch_voice_freq = "-------"
cpdlc_patch_compose_title = ""
cpdlc_patch_compose_text = ""
cpdlc_patch_compose_rsp = 1
cpdlc_patch_compose_return = 0
cpdlc_patch_req_block_low = "-----"
cpdlc_patch_req_block_high = "-----"
cpdlc_patch_req_heading = "---"
cpdlc_patch_req_offset = "-----"
cpdlc_patch_req_wxdev = "-----"
cpdlc_patch_req_pilot_disc = 0
cpdlc_patch_loaded_msg = 0

function cpdlc_patch_trim(s)
	return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

function cpdlc_patch_pad_after(s, n)
	s = s or ""
	if string.len(s) >= n then
		return string.sub(s, 1, n)
	end
	return s .. string.rep(" ", n - string.len(s))
end

function cpdlc_patch_pad_before(s, n)
	s = s or ""
	if string.len(s) >= n then
		return string.sub(s, 1, n)
	end
	return string.rep(" ", n - string.len(s)) .. s
end

function cpdlc_patch_lr(left, right)
	right = right or ""
	if string.len(right) > 23 then
		right = string.sub(right, 1, 23)
	end
	return cpdlc_patch_pad_after(left, 24 - string.len(right)) .. right
end

function cpdlc_patch_layout()
	-- 1 ATC INDEX layout (FANS CDU), 2 CMU layout, 3 DLK layout
	if B738DR_cpdlc == 2 then
		return 1
	elseif B738DR_cmu == 1 then
		return 2
	end
	return 3
end

function cpdlc_patch_title(atc_title, cmu_title, dlk_title)
	local layout = cpdlc_patch_layout()
	if layout == 1 then
		return atc_title
	elseif layout == 2 then
		return cmu_title
	end
	return dlk_title
end

function cpdlc_patch_pages_available()
	return atc_logon_state == 5
end

function cpdlc_patch_active()
	return cpdlc_patch_page ~= 0
end

function cpdlc_patch_in_use()
	if cpdlc_patch_page ~= 0 then
		return 1
	end
	return 0
end

function cpdlc_patch_clear()
	cpdlc_patch_page = 0
end

function cpdlc_patch_open(page)
	page_atc = 0
	page_dl_cpdlc_req_menu = 0
	page_dl_atc = 0
	cpdlc_patch_return = cpdlc_patch_layout()
	cpdlc_patch_page = page
	act_page = 1
	display_update = 1
end

function cpdlc_patch_return_to_index()
	cpdlc_patch_page = 0
	if cpdlc_patch_return == 1 then
		page_atc = 1
	elseif cpdlc_patch_return == 2 then
		page_dl_cpdlc_req_menu = 1
	else
		page_dl_atc = 1
	end
	act_page = 1
	display_update = 1
end

-- ---- number / text helpers --------------------------------------------

function cpdlc_patch_parse_positive_int(s)
	if s == nil or s == "" or string.find(s, "^%d+$") == nil then
		return -1
	end
	return tonumber(s)
end

-- "FL350", "350" (three digits = flight level) or "35000" (feet)
function cpdlc_patch_parse_altitude(s)
	if s == nil or s == "" then
		return nil
	end
	local is_fl = false
	local v = s
	if string.sub(v, 1, 2) == "FL" then
		v = string.sub(v, 3)
		is_fl = true
	end
	local n = cpdlc_patch_parse_positive_int(v)
	if n < 0 then
		return nil
	end
	if is_fl or string.len(v) <= 3 then
		if n > 410 then
			return nil
		end
		return string.format("FL%03d", n)
	end
	if n > 41000 then
		return nil
	end
	return string.format("%d", n)
end

function cpdlc_patch_altitude_text(field)
	local v = cpdlc_patch_trim(field)
	if v == "" or v == "-----" then
		return ""
	end
	if string.sub(v, 1, 2) == "FL" then
		return v
	end
	return v .. " FT"
end

function cpdlc_patch_altitude_feet(field)
	local v = cpdlc_patch_trim(field)
	if string.sub(v, 1, 2) == "FL" then
		return (tonumber(string.sub(v, 3)) or 0) * 100
	end
	return tonumber(v) or 0
end

function cpdlc_patch_transition_altitude()
	local ta = tonumber(trans_alt)
	if ta == nil or ta <= 0 then
		ta = 18000
	end
	return ta
end

function cpdlc_patch_altitude_from_feet(ft)
	if ft < 0 then
		ft = 0
	end
	if ft >= cpdlc_patch_transition_altitude() then
		return string.format("FL%03d", math.floor(ft / 100 + 0.5))
	end
	return string.format("%d", math.floor(ft / 100 + 0.5) * 100)
end

function cpdlc_patch_present_level()
	return cpdlc_patch_altitude_from_feet(simDR_altitude_pilot)
end

function cpdlc_patch_assigned_level()
	return cpdlc_patch_altitude_from_feet(simDR_ap_altitude_dial_ft)
end

-- "250" -> "250"; ".78", "M.78", "M78" -> "M.78"
function cpdlc_patch_parse_speed(s)
	if s == nil or s == "" then
		return nil
	end
	local v = s
	local mach = false
	if string.sub(v, 1, 1) == "M" then
		v = string.sub(v, 2)
		mach = true
	end
	if string.sub(v, 1, 1) == "." then
		v = string.sub(v, 2)
		mach = true
	end
	if mach then
		local n = cpdlc_patch_parse_positive_int(v)
		if n < 0 or string.len(v) ~= 2 or n < 40 or n > 82 then
			return nil
		end
		return "M." .. v
	end
	local n = cpdlc_patch_parse_positive_int(v)
	if n < 100 or n > 340 then
		return nil
	end
	return string.format("%d", n)
end

function cpdlc_patch_speed_text(field)
	local v = cpdlc_patch_trim(field)
	if v == "" or v == "---" then
		return ""
	end
	if string.sub(v, 1, 1) == "M" then
		return v
	end
	return v .. " KT"
end

function cpdlc_patch_present_speed()
	if simDR_altitude_pilot >= 25000 and simDR_mach_no > 0.4 then
		return string.format("M.%02d", math.floor(simDR_mach_no * 100 + 0.5))
	end
	return string.format("%d", math.floor(simDR_airspeed_pilot + 0.5))
end

function cpdlc_patch_parse_heading(s)
	local n = cpdlc_patch_parse_positive_int(s)
	if n < 1 or n > 360 then
		return nil
	end
	return string.format("%03d", n)
end

-- "5L", "L5", "10R", "R10" -> "5NM L"
function cpdlc_patch_parse_offset(s, max_nm)
	if s == nil or string.len(s) < 2 then
		return nil
	end
	local side = ""
	local digits = ""
	for i = 1, string.len(s) do
		local c = string.sub(s, i, i)
		if c == "L" or c == "R" then
			if side ~= "" then
				return nil
			end
			side = c
		elseif string.find(c, "%d") then
			digits = digits .. c
		elseif c ~= "N" and c ~= "M" then
			return nil
		end
	end
	local n = cpdlc_patch_parse_positive_int(digits)
	if side == "" or n < 1 or n > max_nm then
		return nil
	end
	return n .. "NM " .. side
end

function cpdlc_patch_offset_text(field)
	if field == nil or field == "-----" then
		return ""
	end
	local space = string.find(field, " ", 1, true)
	if space == nil then
		return field
	end
	local side = string.sub(field, space + 1)
	if side == "L" then
		side = "LEFT"
	else
		side = "RIGHT"
	end
	return string.sub(field, 1, space - 1) .. " " .. side
end

-- "121.5", "121.500", "12150" -> "121.500"
function cpdlc_patch_parse_frequency(s)
	if s == nil or s == "" then
		return nil
	end
	local v = s
	if string.find(v, ".", 1, true) == nil and string.len(v) >= 5 then
		v = string.sub(v, 1, 3) .. "." .. string.sub(v, 4)
	end
	local f = tonumber(v)
	if f == nil or f < 118 or f > 136.975 then
		return nil
	end
	return string.format("%.3f", f)
end

function cpdlc_patch_parse_hhmm(s)
	if s == nil or string.len(s) ~= 4 then
		return nil
	end
	local n = cpdlc_patch_parse_positive_int(s)
	if n < 0 or math.floor(n / 100) > 23 or (n % 100) > 59 then
		return nil
	end
	return s
end

function cpdlc_patch_ident_valid(s)
	return s ~= nil and string.len(s) >= 2 and string.len(s) <= 5 and string.find(s, "^[A-Z0-9]+$") ~= nil
end

function cpdlc_patch_time_hhmm()
	return string.format("%02d", simDR_zulu_hours) .. string.format("%02d", simDR_zulu_minutes)
end

function cpdlc_patch_wrap24(text)
	local lines = {}
	local line = ""
	for word in string.gmatch(text or "", "%S+") do
		if line == "" then
			line = word
		elseif string.len(line) + 1 + string.len(word) <= 24 then
			line = line .. " " .. word
		else
			table.insert(lines, line)
			line = word
		end
		while string.len(line) > 24 do
			table.insert(lines, string.sub(line, 1, 24))
			line = string.sub(line, 25)
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	return lines
end

-- ---- route data for reports ---------------------------------------------

function cpdlc_patch_route_ident(idx)
	if legs_num == nil or idx == nil or idx < 1 or idx > legs_num then
		return ""
	end
	local id = legs_data[idx][1]
	if id == nil or id == "" or id == "DISCONTINUITY" or id == "-----" then
		return ""
	end
	return cpdlc_patch_trim(id)
end

function cpdlc_patch_route_eta(idx)
	if legs_num == nil or idx == nil or idx < 1 or idx > legs_num then
		return ""
	end
	local h = legs_data[idx][13]
	if h == nil or h == 0 then
		return ""
	end
	h = h % 24
	local hh = math.floor(h)
	local mm = math.floor((h - hh) * 60 + 0.5)
	if mm >= 60 then
		mm = 59
	end
	return string.format("%02d%02d", hh, mm)
end

function cpdlc_patch_position_report()
	local overhead = cpdlc_patch_route_ident(offset - 1)
	local nxt = cpdlc_patch_route_ident(offset)
	local ensuing = cpdlc_patch_route_ident(offset + 1)
	if overhead == "" and nxt == "" then
		return nil
	end
	local msg = "POSITION REPORT"
	if overhead ~= "" then
		msg = msg .. " OVERHEAD " .. overhead .. " AT " .. cpdlc_patch_time_hhmm() .. "Z"
	end
	msg = msg .. " " .. cpdlc_patch_present_level()
	if nxt ~= "" then
		msg = msg .. " ESTIMATING " .. nxt
		local eta = cpdlc_patch_route_eta(offset)
		if eta ~= "" then
			msg = msg .. " AT " .. eta .. "Z"
		end
	end
	if ensuing ~= "" then
		msg = msg .. " NEXT " .. ensuing
	end
	return msg
end

-- ---- message builders ----------------------------------------------------

function cpdlc_patch_req_pending()
	return atc_req_alt ~= "-----" or atc_req_alt_step ~= "-----" or atc_req_spd ~= "---" or atc_req_spd2 ~= "---"
		or atc_req_rte_id ~= "-----" or atc_req_rte_navid ~= "-----" or atc_req_rte_apt ~= "-----"
		or cpdlc_patch_req_block_low ~= "-----" or cpdlc_patch_req_block_high ~= "-----"
		or cpdlc_patch_req_heading ~= "---" or cpdlc_patch_req_offset ~= "-----" or cpdlc_patch_req_wxdev ~= "-----"
end

function cpdlc_patch_req_clear()
	cpdlc_patch_req_block_low = "-----"
	cpdlc_patch_req_block_high = "-----"
	cpdlc_patch_req_heading = "---"
	cpdlc_patch_req_offset = "-----"
	cpdlc_patch_req_wxdev = "-----"
	cpdlc_patch_req_pilot_disc = 0
end

-- DO-258A request text for the CMU request page (replaces dl_atc_build_msg2)
function dl_atc_build_msg2()
	local elements = {}
	if cpdlc_patch_req_block_low ~= "-----" and cpdlc_patch_req_block_high ~= "-----" then
		table.insert(elements, "REQUEST BLOCK " .. cpdlc_patch_altitude_text(cpdlc_patch_req_block_low) .. " TO " .. cpdlc_patch_altitude_text(cpdlc_patch_req_block_high))
	else
		local alt_field = atc_req_alt
		if alt_field == "-----" then
			alt_field = atc_req_alt_step
		end
		local alt_text = cpdlc_patch_altitude_text(alt_field)
		if alt_text ~= "" then
			local target = cpdlc_patch_altitude_feet(alt_field)
			if target > simDR_altitude_pilot + 300 then
				table.insert(elements, "REQUEST CLIMB TO " .. alt_text)
			elseif target < simDR_altitude_pilot - 300 then
				table.insert(elements, "REQUEST DESCENT TO " .. alt_text)
			else
				table.insert(elements, "REQUEST " .. alt_text)
			end
		end
	end
	if atc_req_spd ~= "---" then
		table.insert(elements, "REQUEST " .. cpdlc_patch_trim(atc_req_spd) .. " KT")
	elseif atc_req_spd2 ~= "---" then
		table.insert(elements, "REQUEST M" .. cpdlc_patch_trim(atc_req_spd2))
	end
	if atc_req_rte_id ~= "-----" then
		table.insert(elements, "REQUEST DIRECT TO " .. atc_req_rte_id)
	elseif atc_req_rte_navid ~= "-----" then
		table.insert(elements, "REQUEST DIRECT TO " .. atc_req_rte_navid)
	elseif atc_req_rte_apt ~= "-----" then
		table.insert(elements, "REQUEST DIRECT TO " .. atc_req_rte_apt)
	end
	if cpdlc_patch_req_heading ~= "---" then
		table.insert(elements, "REQUEST HEADING " .. cpdlc_patch_req_heading)
	end
	if cpdlc_patch_req_offset ~= "-----" then
		table.insert(elements, "REQUEST OFFSET " .. cpdlc_patch_offset_text(cpdlc_patch_req_offset) .. " OF ROUTE")
	end
	if cpdlc_patch_req_wxdev ~= "-----" then
		table.insert(elements, "REQUEST WEATHER DEVIATION UP TO " .. cpdlc_patch_offset_text(cpdlc_patch_req_wxdev) .. " OF ROUTE")
	end
	local msg = ""
	for i = 1, #elements do
		if msg ~= "" then
			msg = msg .. ". "
		end
		msg = msg .. elements[i]
	end
	req_msg_n = 0
	if msg == "" then
		return
	end
	if atc_req_alt_due == 1 then
		msg = msg .. " DUE TO WEATHER"
	elseif atc_req_alt_due == 2 then
		msg = msg .. " DUE TO AIRCRAFT PERFORMANCE"
	end
	if cpdlc_patch_req_pilot_disc ~= 0 then
		msg = msg .. " AT PILOTS DISCRETION"
	end
	req_msg_n = 1
	req_msg[1] = msg
end

function cpdlc_patch_emergency_message()
	local elements = {}
	if cpdlc_patch_emerg_type == 1 then
		table.insert(elements, "MAYDAY MAYDAY MAYDAY")
	elseif cpdlc_patch_emerg_type == 2 then
		table.insert(elements, "PAN PAN PAN")
	end
	if cpdlc_patch_emerg_descend ~= "-----" then
		table.insert(elements, "DESCENDING TO " .. cpdlc_patch_altitude_text(cpdlc_patch_emerg_descend))
	end
	if cpdlc_patch_emerg_divert ~= "-----" then
		table.insert(elements, "DIVERTING TO " .. cpdlc_patch_emerg_divert)
	end
	if cpdlc_patch_emerg_offset ~= "-----" then
		table.insert(elements, "OFFSETTING " .. cpdlc_patch_offset_text(cpdlc_patch_emerg_offset) .. " OF ROUTE")
	end
	if cpdlc_patch_emerg_fuel ~= "----" or cpdlc_patch_emerg_souls ~= "---" then
		local e = ""
		if cpdlc_patch_emerg_fuel ~= "----" then
			e = cpdlc_patch_emerg_fuel .. " OF FUEL REMAINING"
		end
		if cpdlc_patch_emerg_souls ~= "---" then
			if e ~= "" then
				e = e .. " AND "
			end
			e = e .. cpdlc_patch_emerg_souls .. " SOULS ON BOARD"
		end
		table.insert(elements, e)
	end
	local msg = ""
	for i = 1, #elements do
		if msg ~= "" then
			msg = msg .. ". "
		end
		msg = msg .. elements[i]
	end
	return msg
end

function cpdlc_patch_emergency_clear()
	cpdlc_patch_emerg_type = 0
	cpdlc_patch_emerg_descend = "-----"
	cpdlc_patch_emerg_divert = "-----"
	cpdlc_patch_emerg_offset = "-----"
	cpdlc_patch_emerg_fuel = "----"
	cpdlc_patch_emerg_souls = "---"
end

-- ---- downlink send (same store semantics as the stock request SEND) -------

function cpdlc_patch_send(text, rsp)
	if text == nil or text == "" then
		return false
	end
	if atc_logon == "********" or atc_logon == "" then
		return false
	end
	atc_msg_shift()
	atc_msg_txt[1] = text
	atc_msg_rcv_snd[1] = 1
	atc_msg_cpdlc_dn[1] = atc_send_buf_n
	atc_msg_cpdlc_up[1] = 0
	atc_msg_rsp[1] = rsp
	atc_msg_time[1] = cpdlc_patch_time_hhmm()
	atc_msg_from[1] = ""
	if rsp ~= 0 then
		atc_msg_status[1] = 2		--"OPEN"
		atc_msg_timer[1] = 270
	else
		atc_msg_status[1] = 9		--"SENT"
		atc_msg_timer[1] = 0
	end
	atc_resp_state = 4
	atc_resp_state_timer = 2
	send_cpdlc(1)
	return true
end

function cpdlc_patch_compose_open(title, text, rsp)
	if text == nil or text == "" then
		return
	end
	cpdlc_patch_compose_title = title
	cpdlc_patch_compose_text = text
	cpdlc_patch_compose_rsp = rsp
	cpdlc_patch_compose_return = cpdlc_patch_page
	cpdlc_patch_page = 6
	act_page = 1
	display_update = 1
end

-- ---- loadable DIRECT TO clearance (same path as the stock 4R LOAD) -------

function cpdlc_patch_direct_loadable()
	return atc_uplink_pending_menu ~= 0 and atc_proc_dir ~= "" and legs_delete == 0
		and cpdlc_patch_loaded_msg ~= atc_msg_log_cur and (rte12_act == 0 or rte12_act == 1)
end

function cpdlc_patch_load_direct()
	if not cpdlc_patch_direct_loadable() then
		return false
	end
	local res_item = find_act_route_wpt2(atc_proc_dir, offset, rte12_act)
	if res_item == 0 then
		return false
	end
	create_legs_abeam_list(offset, res_item - 1, rte12_act)
	rte_copy(res_item, rte12_act)
	rte_paste(offset, rte12_act)
	calc_rte_enable2 = 1
	local nd_lat2 = 0
	local nd_lon2 = 0
	if rte12_act == 0 then
		legs_data2[offset][31] = "DF"
		legs_data2[offset][9] = ""
		nd_lat2, nd_lon2 = lat_lon_legs2(offset)
	else
		legs_data8[offset][31] = "DF"
		legs_data8[offset][9] = ""
		nd_lat2, nd_lon2 = lat_lon_legs8(offset)
	end
	-- intentional fix: the stock LOAD compares an undefined global here and never
	-- arms the intercept course; use the gear-on-ground datarefs like LEGS 1L does.
	local patch_on_ground = false
	if simDR_on_ground[0] == 1 or simDR_on_ground[1] == 1 or simDR_on_ground[2] == 1 then
		patch_on_ground = true
	end
	if patch_on_ground == false then
		legs_intdir = 1
		legs_intdir_rte = rte12_act
		legs_intdir_idx_mod = offset
		local nd_lat = math.rad(simDR_latitude)
		local nd_lon = math.rad(simDR_longitude)
		nd_lat2 = math.rad(nd_lat2)
		nd_lon2 = math.rad(nd_lon2)
		local nd_y = math.sin(nd_lon2 - nd_lon) * math.cos(nd_lat2)
		local nd_x = math.cos(nd_lat) * math.sin(nd_lat2) - math.sin(nd_lat) * math.cos(nd_lat2) * math.cos(nd_lon2 - nd_lon)
		local nd_hdg = math.deg(math.atan2(nd_y, nd_x))
		nd_hdg = (nd_hdg + 360) % 360
		legs_intdir_crs_mod = (nd_hdg + simDR_mag_variation + 360) % 360
	end
	legs_delete = 1
	msg_unavaible_crz_alt = 0
	cpdlc_patch_loaded_msg = atc_msg_log_cur
	return true
end

-- ---- drawing -------------------------------------------------------------

function cpdlc_patch_footer(right)
	local layout = cpdlc_patch_layout()
	if layout == 1 then
		line6_x = "------------------------"
		line6_l = cpdlc_patch_lr("<ATC INDEX", right)
	else
		line6_l = cpdlc_patch_lr("<RETURN", right)
		line6_x = "     " .. vhf_in_prog
	end
end

function cpdlc_patch_draw_when()
	max_page_buf = 1
	line0_l = cpdlc_patch_title("      WHEN CAN WE       ", "CPDLC-WHEN CAN WE       ", "   DLK ATC WHEN CAN WE  ")
	line1_l = cpdlc_patch_lr("<HIGHER ALT", "LOWER ALT>")
	line2_x = " CLIMB TO     DESCEND TO"
	line2_l = cpdlc_patch_lr("<" .. cpdlc_patch_when_climb, cpdlc_patch_when_descend .. ">")
	line3_x = "                   SPEED"
	line3_l = cpdlc_patch_lr("<BACK ON ROUTE", cpdlc_patch_when_speed .. ">")
	line4_x = " CRUISE CLIMB TO        "
	line4_l = "<" .. cpdlc_patch_when_cruise
	cpdlc_patch_footer("")
end

function cpdlc_patch_draw_report()
	max_page_buf = 1
	local present = cpdlc_patch_present_level()
	local passing = cpdlc_patch_rep_passing
	if passing == "-----" then
		local overhead = cpdlc_patch_route_ident(offset - 1)
		if overhead ~= "" then
			passing = overhead
		end
	end
	local leaving = cpdlc_patch_rep_leaving
	if leaving == "-----" then
		leaving = present
	end
	line0_l = cpdlc_patch_title("       ATC REPORT       ", "CPDLC-REPORT            ", "     DLK ATC REPORT     ")
	line1_x = " LEAVING           LEVEL"
	line1_l = cpdlc_patch_lr("<" .. leaving, present .. ">")
	line2_x = " CLIMBING TO  DESCENDING"
	line2_l = cpdlc_patch_lr("<" .. cpdlc_patch_rep_climbing, cpdlc_patch_rep_descending .. ">")
	line3_x = " PASSING   BACK ON ROUTE"
	line3_l = cpdlc_patch_lr("<" .. passing, "SEND>")
	line4_x = " ASSIGNED ALT   ASSIGNED"
	line4_l = cpdlc_patch_lr("<" .. cpdlc_patch_assigned_level(), "SPD " .. cpdlc_patch_rep_assigned_spd .. ">")
	line5_x = " PRESENT SPEED          "
	line5_l = "<" .. cpdlc_patch_present_speed()
	cpdlc_patch_footer("")
end

function cpdlc_patch_draw_posrep()
	max_page_buf = 1
	local overhead = cpdlc_patch_route_ident(offset - 1)
	local nxt = cpdlc_patch_route_ident(offset)
	local ensuing = cpdlc_patch_route_ident(offset + 1)
	local eta = cpdlc_patch_route_eta(offset)
	if overhead == "" then overhead = "-----" end
	if nxt == "" then nxt = "-----" end
	if ensuing == "" then ensuing = "-----" end
	if eta == "" then eta = "----" else eta = eta .. "Z" end
	line0_l = cpdlc_patch_title("    POSITION REPORT     ", "CPDLC-POSITION REPORT   ", "   DLK ATC POS REPORT   ")
	line1_x = " OVERHEAD           TIME"
	line1_l = cpdlc_patch_lr(" " .. overhead, cpdlc_patch_time_hhmm() .. "Z")
	line2_x = " ALTITUDE           NEXT"
	line2_l = cpdlc_patch_lr(" " .. cpdlc_patch_present_level(), nxt)
	line3_x = " ETA             ENSUING"
	line3_l = cpdlc_patch_lr(" " .. eta, ensuing)
	line4_x = " SPEED                  "
	line4_l = " " .. cpdlc_patch_present_speed()
	if cpdlc_patch_position_report() ~= nil then
		cpdlc_patch_footer("VERIFY>")
	else
		cpdlc_patch_footer("")
	end
end

function cpdlc_patch_draw_emergency()
	max_page_buf = 1
	line0_l = cpdlc_patch_title("     ATC EMERGENCY      ", "CPDLC-EMERGENCY         ", "   DLK ATC EMERGENCY    ")
	local mayday = "<MAYDAY"
	local pan = "PAN PAN>"
	if cpdlc_patch_emerg_type == 1 then
		mayday = "<MAYDAY (SEL)"
	elseif cpdlc_patch_emerg_type == 2 then
		pan = "(SEL) PAN PAN>"
	end
	line1_l = cpdlc_patch_lr(mayday, pan)
	line2_x = " DESCENDING TO DIVERT TO"
	line2_l = cpdlc_patch_lr("<" .. cpdlc_patch_emerg_descend, cpdlc_patch_emerg_divert .. ">")
	line3_x = " OFFSETTING   FUEL/SOULS"
	line3_l = cpdlc_patch_lr("<" .. cpdlc_patch_emerg_offset, cpdlc_patch_emerg_fuel .. "/" .. cpdlc_patch_emerg_souls .. ">")
	line4_l = "<CANCEL EMERGENCY       "
	line5_l = "<ERASE                  "
	if cpdlc_patch_emergency_message() ~= "" then
		cpdlc_patch_footer("VERIFY>")
	else
		cpdlc_patch_footer("")
	end
end

function cpdlc_patch_draw_voice()
	max_page_buf = 1
	line0_l = cpdlc_patch_title("       ATC VOICE        ", "CPDLC-VOICE             ", "     DLK ATC VOICE      ")
	line1_x = " FREQUENCY              "
	line1_l = "<" .. cpdlc_patch_voice_freq
	line2_l = "<REQUEST VOICE CONTACT  "
	cpdlc_patch_footer("")
end

function cpdlc_patch_draw_compose()
	local lines = cpdlc_patch_wrap24(cpdlc_patch_compose_text)
	local max_page_calc = math.floor((math.max(1, #lines) - 1) / 7) + 1
	max_page_buf = max_page_calc
	if act_page_buf < 1 or act_page_buf > max_page_calc then
		act_page_buf = 1
	end
	line0_l = cpdlc_patch_pad_after(cpdlc_patch_compose_title, 24)
	line0_s = "                    " .. act_page_buf .. "/" .. max_page_calc
	local first = (act_page_buf - 1) * 7
	local slots = { "line1_s", "line2_x", "line2_s", "line3_x", "line3_s", "line4_x", "line4_s" }
	for i = 1, 7 do
		local txt = lines[first + i]
		if txt ~= nil then
			if slots[i] == "line1_s" then line1_s = txt
			elseif slots[i] == "line2_x" then line2_x = txt
			elseif slots[i] == "line2_s" then line2_s = txt
			elseif slots[i] == "line3_x" then line3_x = txt
			elseif slots[i] == "line3_s" then line3_s = txt
			elseif slots[i] == "line4_x" then line4_x = txt
			else line4_s = txt end
		end
	end
	if cpdlc_patch_layout() == 1 then
		line5_l = "                   SEND>"
	else
		line5_l = "                   SEND="
	end
	cpdlc_patch_footer("")
	line6_l = "<RETURN                 "
end

function cpdlc_patch_draw()
	if cpdlc_patch_page == 1 then
		cpdlc_patch_draw_when()
	elseif cpdlc_patch_page == 2 then
		cpdlc_patch_draw_report()
	elseif cpdlc_patch_page == 3 then
		cpdlc_patch_draw_posrep()
	elseif cpdlc_patch_page == 4 then
		cpdlc_patch_draw_emergency()
	elseif cpdlc_patch_page == 5 then
		cpdlc_patch_draw_voice()
	elseif cpdlc_patch_page == 6 then
		cpdlc_patch_draw_compose()
	end
end

-- Overlay on stock pages: ATC INDEX (FANS layout), DLK ATC MENU, CPDLC
-- REPORTS/REQUESTS menu, CMU request page 2, LOAD prompt on message pages.
function cpdlc_patch_overlay()
	if cpdlc_patch_page ~= 0 then
		null_fmc_disp()
		cpdlc_patch_draw()
		return
	end
	local on = cpdlc_patch_pages_available()
	if page_atc == 1 and B738DR_cpdlc == 2 then
		local a = "<"
		if not on then a = " " end
		local r_pos = "POS REPORT>"
		local r_when = "WHEN CAN WE>"
		local r_voice = "VOICE>"
		if not on then
			r_pos = "POS REPORT "
			r_when = "WHEN CAN WE "
			r_voice = "VOICE "
		end
		line1_l = cpdlc_patch_lr(a .. "EMERGENCY", r_pos)
		line2_l = cpdlc_patch_lr(a .. "REQUEST", r_when)
		line3_l = cpdlc_patch_lr(a .. "REPORT", "FREE TEXT>")
		line4_l = "<LOG            MONITOR>"
		line5_l = cpdlc_patch_lr("<LOGON/STATUS", r_voice)
	elseif page_dl_atc == 1 then
		local a = "<"
		if not on then a = " " end
		local r_when = "WHEN CAN WE>"
		local r_emerg = "EMERGENCY>"
		local r_voice = "VOICE>"
		if not on then
			r_when = "WHEN CAN WE "
			r_emerg = "EMERGENCY "
			r_voice = "VOICE "
		end
		line1_l = cpdlc_patch_lr("<REQUEST", r_when)
		line2_l = cpdlc_patch_lr(a .. "REPORT", r_emerg)
		line3_l = cpdlc_patch_lr("<FREE TEXT", r_voice)
		line4_l = cpdlc_patch_lr(a .. "POS REPORT", "")
	elseif page_dl_cpdlc_req_menu == 1 then
		line1_l = cpdlc_patch_lr("<REQ ALT/SPD/DIR", "VOICE>")
		line2_l = cpdlc_patch_lr("<WHEN CAN WE", "EMERGENCY>")
		line3_l = cpdlc_patch_lr("<REPORT", "POS REPORT>")
		line4_l = "<REQ WX DEV             "
	elseif page_dl_cpdlc_req == 1 then
		max_page_buf = 2
		if act_page_buf == 2 then
			null_fmc_disp()
			local pending = cpdlc_patch_req_pending()
			line0_l = "CPDLC-REQ ALT/SPD/DIRECT"
			line0_s = "                    2/2 "
			line1_x = "BLOCK LOW     BLOCK HIGH"
			line1_l = cpdlc_patch_lr(cpdlc_patch_req_block_low, cpdlc_patch_req_block_high)
			line2_x = "HEADING           OFFSET"
			line2_l = cpdlc_patch_lr(cpdlc_patch_req_heading, cpdlc_patch_req_offset)
			line3_x = "WX DEVIATION            "
			line3_l = cpdlc_patch_req_wxdev
			line4_x = "AT PILOTS DISC          "
			if cpdlc_patch_req_pilot_disc ~= 0 then line4_l = "YES" else line4_l = "NO" end
			line5_x = "DUE TO                  "
			local due = " NONE"
			if atc_req_alt_due == 1 then due = " WEATHER" elseif atc_req_alt_due == 2 then due = " AIRCRAFT PERF" end
			if pending then
				line5_l = cpdlc_patch_lr(due, "VERIFY>")
			else
				line5_l = due
			end
			line6_l = "<RETURN                 "
			line6_x = "     " .. vhf_in_prog
		else
			line0_s = "                    1/2 "
			if cpdlc_patch_req_pending() and atc_uplink_pending_menu == 0 then
				line5_l = cpdlc_patch_lr(string.sub(line5_l, 1, 15), "VERIFY>")
			end
		end
	elseif page_dl_cpdlc_message == 1 and cpdlc_patch_direct_loadable() then
		if B738DR_cmu == 1 then
			line5_l = cpdlc_patch_lr("=LOAD", string.sub(line5_l, 17))
		else
			line4_l = cpdlc_patch_lr(string.sub(line4_l, 1, 12), "LOAD>")
		end
	elseif page_dl_cpdlc_message == 1 and cpdlc_patch_loaded_msg == atc_msg_log_cur and atc_uplink_pending_menu ~= 0 then
		if B738DR_cmu == 1 then
			line5_l = cpdlc_patch_lr(" LOADED", string.sub(line5_l, 17))
		else
			line4_l = cpdlc_patch_lr(string.sub(line4_l, 1, 12), "LOADED")
		end
	end
end

-- ---- key handling --------------------------------------------------------

function cpdlc_patch_entry_field(current, default, parser, arg)
	-- returns new value, or nil on invalid entry (message already raised)
	if entry == ">DELETE" then
		entry = ""
		return default
	elseif entry ~= "" then
		local v
		if arg ~= nil then
			v = parser(entry, arg)
		else
			v = parser(entry)
		end
		if v == nil then
			add_fmc_msg(INVALID_INPUT, 0, 0)
			return nil
		end
		entry = ""
		return v
	end
	return current
end

function cpdlc_patch_lsk_when(key)
	if key == "6L" then
		cpdlc_patch_return_to_index()
	elseif key == "1L" then
		cpdlc_patch_compose_open("WHEN CAN WE", "WHEN CAN WE EXPECT HIGHER ALTITUDE", 1)
	elseif key == "1R" then
		cpdlc_patch_compose_open("WHEN CAN WE", "WHEN CAN WE EXPECT LOWER ALTITUDE", 1)
	elseif key == "3L" then
		cpdlc_patch_compose_open("WHEN CAN WE", "WHEN CAN WE EXPECT BACK ON ROUTE", 1)
	elseif key == "2L" or key == "2R" or key == "4L" then
		local current = cpdlc_patch_when_climb
		if key == "2R" then current = cpdlc_patch_when_descend elseif key == "4L" then current = cpdlc_patch_when_cruise end
		local v = cpdlc_patch_entry_field(current, "-----", cpdlc_patch_parse_altitude)
		if v ~= nil then
			if key == "2L" then cpdlc_patch_when_climb = v elseif key == "2R" then cpdlc_patch_when_descend = v else cpdlc_patch_when_cruise = v end
			if v ~= "-----" then
				local prefix = "WHEN CAN WE EXPECT CLIMB TO "
				if key == "2R" then prefix = "WHEN CAN WE EXPECT DESCENT TO " elseif key == "4L" then prefix = "WHEN CAN WE EXPECT CRUISE CLIMB TO " end
				cpdlc_patch_compose_open("WHEN CAN WE", prefix .. cpdlc_patch_altitude_text(v), 1)
			end
		end
	elseif key == "3R" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_when_speed, "---", cpdlc_patch_parse_speed)
		if v ~= nil then
			cpdlc_patch_when_speed = v
			if v ~= "---" then
				cpdlc_patch_compose_open("WHEN CAN WE", "WHEN CAN WE EXPECT " .. cpdlc_patch_speed_text(v), 1)
			end
		end
	end
end

function cpdlc_patch_lsk_report(key)
	if key == "6L" then
		cpdlc_patch_return_to_index()
	elseif key == "1L" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_rep_leaving, "-----", cpdlc_patch_parse_altitude)
		if v ~= nil then
			cpdlc_patch_rep_leaving = v
			if v == "-----" then v = cpdlc_patch_present_level() end
			cpdlc_patch_compose_open("ATC REPORT", "LEAVING " .. cpdlc_patch_altitude_text(v), 0)
		end
	elseif key == "1R" then
		cpdlc_patch_compose_open("ATC REPORT", "LEVEL " .. cpdlc_patch_altitude_text(cpdlc_patch_present_level()), 0)
	elseif key == "2L" or key == "2R" then
		local current = cpdlc_patch_rep_climbing
		if key == "2R" then current = cpdlc_patch_rep_descending end
		local v = cpdlc_patch_entry_field(current, "-----", cpdlc_patch_parse_altitude)
		if v ~= nil then
			if key == "2L" then cpdlc_patch_rep_climbing = v else cpdlc_patch_rep_descending = v end
			if v ~= "-----" then
				local prefix = "CLIMBING TO "
				if key == "2R" then prefix = "DESCENDING TO " end
				cpdlc_patch_compose_open("ATC REPORT", prefix .. cpdlc_patch_altitude_text(v), 0)
			end
		end
	elseif key == "3L" then
		if entry == ">DELETE" then
			cpdlc_patch_rep_passing = "-----"
			entry = ""
		elseif entry ~= "" then
			if cpdlc_patch_ident_valid(entry) then
				cpdlc_patch_rep_passing = entry
				entry = ""
			else
				add_fmc_msg(INVALID_INPUT, 0, 0)
				return
			end
		end
		local ident = cpdlc_patch_rep_passing
		if ident == "-----" then
			ident = cpdlc_patch_route_ident(offset - 1)
		end
		if ident ~= "" and ident ~= "-----" then
			cpdlc_patch_compose_open("ATC REPORT", "PASSING " .. ident, 0)
		end
	elseif key == "3R" then
		cpdlc_patch_compose_open("ATC REPORT", "BACK ON ROUTE", 0)
	elseif key == "4L" then
		cpdlc_patch_compose_open("ATC REPORT", "ASSIGNED ALTITUDE " .. cpdlc_patch_altitude_text(cpdlc_patch_assigned_level()), 0)
	elseif key == "4R" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_rep_assigned_spd, "---", cpdlc_patch_parse_speed)
		if v ~= nil then
			cpdlc_patch_rep_assigned_spd = v
			if v ~= "---" then
				cpdlc_patch_compose_open("ATC REPORT", "ASSIGNED SPEED " .. cpdlc_patch_speed_text(v), 0)
			end
		end
	elseif key == "5L" then
		cpdlc_patch_compose_open("ATC REPORT", "PRESENT SPEED " .. cpdlc_patch_speed_text(cpdlc_patch_present_speed()), 0)
	end
end

function cpdlc_patch_lsk_posrep(key)
	if key == "6L" then
		cpdlc_patch_return_to_index()
	elseif key == "6R" then
		local msg = cpdlc_patch_position_report()
		if msg == nil then
			add_fmc_msg("NO ACTIVE ROUTE", 0, 0)
		else
			cpdlc_patch_compose_open("POSITION REPORT", msg, 0)
		end
	end
end

function cpdlc_patch_lsk_emergency(key)
	if key == "6L" then
		cpdlc_patch_return_to_index()
	elseif key == "1L" then
		if cpdlc_patch_emerg_type == 1 then cpdlc_patch_emerg_type = 0 else cpdlc_patch_emerg_type = 1 end
	elseif key == "1R" then
		if cpdlc_patch_emerg_type == 2 then cpdlc_patch_emerg_type = 0 else cpdlc_patch_emerg_type = 2 end
	elseif key == "2L" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_emerg_descend, "-----", cpdlc_patch_parse_altitude)
		if v ~= nil then cpdlc_patch_emerg_descend = v end
	elseif key == "2R" then
		if entry == ">DELETE" then
			cpdlc_patch_emerg_divert = "-----"
			entry = ""
		elseif entry ~= "" then
			if cpdlc_patch_ident_valid(entry) then
				cpdlc_patch_emerg_divert = entry
				entry = ""
			else
				add_fmc_msg(INVALID_INPUT, 0, 0)
			end
		end
	elseif key == "3L" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_emerg_offset, "-----", cpdlc_patch_parse_offset, 99)
		if v ~= nil then cpdlc_patch_emerg_offset = v end
	elseif key == "3R" then
		-- "HHMM/SOULS", "HHMM/" or "/SOULS"
		if entry == ">DELETE" then
			cpdlc_patch_emerg_fuel = "----"
			cpdlc_patch_emerg_souls = "---"
			entry = ""
		elseif entry ~= "" then
			local slash = string.find(entry, "/", 1, true)
			local fuel = entry
			local souls = ""
			if slash ~= nil then
				fuel = string.sub(entry, 1, slash - 1)
				souls = string.sub(entry, slash + 1)
			end
			local ok = true
			local fuel_v = nil
			if fuel ~= "" then
				fuel_v = cpdlc_patch_parse_hhmm(fuel)
				if fuel_v == nil then ok = false end
			end
			local souls_v = 0
			if souls ~= "" then
				souls_v = cpdlc_patch_parse_positive_int(souls)
				if souls_v < 1 or souls_v > 999 then ok = false end
			end
			if ok then
				if fuel_v ~= nil then cpdlc_patch_emerg_fuel = fuel_v end
				if souls ~= "" then cpdlc_patch_emerg_souls = string.format("%d", souls_v) end
				entry = ""
			else
				add_fmc_msg(INVALID_INPUT, 0, 0)
			end
		end
	elseif key == "4L" then
		cpdlc_patch_emergency_clear()
		cpdlc_patch_compose_open("ATC EMERGENCY", "CANCEL EMERGENCY", 1)
	elseif key == "5L" then
		cpdlc_patch_emergency_clear()
	elseif key == "6R" then
		cpdlc_patch_compose_open("ATC EMERGENCY", cpdlc_patch_emergency_message(), 1)
	end
end

function cpdlc_patch_lsk_voice(key)
	if key == "6L" then
		cpdlc_patch_return_to_index()
	elseif key == "1L" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_voice_freq, "-------", cpdlc_patch_parse_frequency)
		if v ~= nil then cpdlc_patch_voice_freq = v end
	elseif key == "2L" then
		local msg = "REQUEST VOICE CONTACT"
		if cpdlc_patch_voice_freq ~= "-------" then
			msg = msg .. " " .. cpdlc_patch_voice_freq
		end
		cpdlc_patch_compose_open("ATC VOICE", msg, 1)
	end
end

function cpdlc_patch_lsk_compose(key)
	if key == "6L" then
		cpdlc_patch_page = cpdlc_patch_compose_return
		if cpdlc_patch_page == 0 or cpdlc_patch_page == 6 then
			cpdlc_patch_return_to_index()
		end
		act_page = 1
	elseif key == "5R" then
		if cpdlc_patch_send(cpdlc_patch_compose_text, cpdlc_patch_compose_rsp) then
			cpdlc_patch_when_climb = "-----"
			cpdlc_patch_when_descend = "-----"
			cpdlc_patch_when_speed = "---"
			cpdlc_patch_when_cruise = "-----"
			cpdlc_patch_rep_leaving = "-----"
			cpdlc_patch_rep_climbing = "-----"
			cpdlc_patch_rep_descending = "-----"
			cpdlc_patch_rep_passing = "-----"
			cpdlc_patch_rep_assigned_spd = "---"
			cpdlc_patch_compose_text = ""
			cpdlc_patch_return_to_index()
		else
			add_fmc_msg("NO COMM", 0, 0)
		end
	end
end

-- keys on the CMU request page 2 (BLOCK / HEADING / OFFSET / WX DEV / PILOT DISC)
function cpdlc_patch_lsk_req_page2(key)
	if key == "6L" then
		page_dl_cpdlc_req = 0
		page_dl_cpdlc_req_menu = 1
		act_page = 1
	elseif key == "1L" or key == "1R" then
		local current = cpdlc_patch_req_block_low
		if key == "1R" then current = cpdlc_patch_req_block_high end
		local v = cpdlc_patch_entry_field(current, "-----", cpdlc_patch_parse_altitude)
		if v ~= nil then
			if key == "1L" then cpdlc_patch_req_block_low = v else cpdlc_patch_req_block_high = v end
			if cpdlc_patch_req_block_low ~= "-----" and cpdlc_patch_req_block_high ~= "-----" then
				if cpdlc_patch_altitude_feet(cpdlc_patch_req_block_low) >= cpdlc_patch_altitude_feet(cpdlc_patch_req_block_high) then
					if key == "1L" then cpdlc_patch_req_block_low = "-----" else cpdlc_patch_req_block_high = "-----" end
					add_fmc_msg(INVALID_INPUT, 0, 0)
				else
					atc_req_alt = "-----"
					atc_req_alt_step = "-----"
				end
			end
		end
	elseif key == "2L" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_req_heading, "---", cpdlc_patch_parse_heading)
		if v ~= nil then cpdlc_patch_req_heading = v end
	elseif key == "2R" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_req_offset, "-----", cpdlc_patch_parse_offset, 99)
		if v ~= nil then cpdlc_patch_req_offset = v end
	elseif key == "3L" then
		local v = cpdlc_patch_entry_field(cpdlc_patch_req_wxdev, "-----", cpdlc_patch_parse_offset, 99)
		if v ~= nil then cpdlc_patch_req_wxdev = v end
	elseif key == "4L" then
		if cpdlc_patch_req_pilot_disc ~= 0 then cpdlc_patch_req_pilot_disc = 0 else cpdlc_patch_req_pilot_disc = 1 end
	elseif key == "5L" then
		atc_req_alt_due = (atc_req_alt_due + 1) % 3
	elseif key == "5R" then
		if cpdlc_patch_req_pending() then
			page_dl_cpdlc_req = 0
			page_dl_cpdlc_req_ver = 1
			act_page = 1
			dl_atc_build_msg2()
		end
	end
end

-- returns true when the key was consumed by the patch
function cpdlc_patch_lsk(key)
	local consumed = true
	if cpdlc_patch_page == 1 then
		cpdlc_patch_lsk_when(key)
	elseif cpdlc_patch_page == 2 then
		cpdlc_patch_lsk_report(key)
	elseif cpdlc_patch_page == 3 then
		cpdlc_patch_lsk_posrep(key)
	elseif cpdlc_patch_page == 4 then
		cpdlc_patch_lsk_emergency(key)
	elseif cpdlc_patch_page == 5 then
		cpdlc_patch_lsk_voice(key)
	elseif cpdlc_patch_page == 6 then
		cpdlc_patch_lsk_compose(key)
	elseif page_atc == 1 and B738DR_cpdlc == 2 then
		local on = cpdlc_patch_pages_available()
		if key == "1L" and on then
			cpdlc_patch_open(4)
		elseif key == "1R" and on then
			cpdlc_patch_open(3)
		elseif key == "2R" and on then
			cpdlc_patch_open(1)
		elseif key == "3L" and on then
			cpdlc_patch_open(2)
		elseif key == "3R" then
			page_atc = 0
			page_atc_free_txt = 1
			act_page = 1
		elseif key == "5R" and on then
			cpdlc_patch_open(5)
		else
			consumed = false
		end
	elseif page_dl_atc == 1 then
		local on = cpdlc_patch_pages_available()
		if key == "2L" and on then
			cpdlc_patch_open(2)
		elseif key == "4L" and on then
			cpdlc_patch_open(3)
		elseif key == "1R" and on then
			cpdlc_patch_open(1)
		elseif key == "2R" and on then
			cpdlc_patch_open(4)
		elseif key == "3R" and on then
			cpdlc_patch_open(5)
		else
			consumed = false
		end
	elseif page_dl_cpdlc_req_menu == 1 then
		if key == "2L" then
			cpdlc_patch_open(1)
		elseif key == "3L" then
			cpdlc_patch_open(2)
		elseif key == "4L" then
			page_dl_cpdlc_req_menu = 0
			page_dl_cpdlc_req = 1
			act_page = 2
		elseif key == "1R" then
			cpdlc_patch_open(5)
		elseif key == "2R" then
			cpdlc_patch_open(4)
		elseif key == "3R" then
			cpdlc_patch_open(3)
		else
			consumed = false
		end
	elseif page_dl_cpdlc_req == 1 and act_page == 2 then
		cpdlc_patch_lsk_req_page2(key)
	elseif page_dl_cpdlc_req == 1 and key == "5R" and cpdlc_patch_req_pending() and atc_uplink_pending_menu == 0 then
		page_dl_cpdlc_req = 0
		page_dl_cpdlc_req_ver = 1
		act_page = 1
		dl_atc_build_msg2()
	elseif page_dl_cpdlc_req_ver == 1 and key == "6L" then
		-- stock RETURN resets the stock fields; reset ours too and let stock continue
		cpdlc_patch_req_clear()
		consumed = false
	elseif page_dl_cpdlc_req_ver == 1 and key == "5R" then
		-- stock SEND; clear our fields afterwards is not possible, so send here
		if req_msg_n ~= 0 then
			local answer_msg = req_msg[1]
			if req_msg_n > 1 then
				for ggg = 2, req_msg_n do
					answer_msg = answer_msg .. " " .. req_msg[ggg]
				end
			end
			if cpdlc_patch_send(answer_msg, 1) then
				page_dl_cpdlc_req_ver = 0
				page_dl_cpdlc_req = 1
				act_page = 1
				atc_req_alt = "-----"
				atc_req_alt_step = "-----"
				atc_req_alt_due = 0
				atc_req_spd = "---"
				atc_req_spd2 = "---"
				atc_req_rte_id = "-----"
				atc_req_rte_navid = "-----"
				atc_req_rte_apt = "-----"
				cpdlc_patch_req_clear()
				req_msg_n = 0
			else
				add_fmc_msg("NO COMM", 0, 0)
			end
		end
	elseif page_dl_cpdlc_message == 1 and cpdlc_patch_direct_loadable()
		and ((B738DR_cmu == 1 and key == "5L") or (B738DR_cmu ~= 1 and key == "4R")) then
		if not cpdlc_patch_load_direct() then
			add_fmc_msg("UNLOADABLE CLEARANCE", 0, 0)
		end
	else
		consumed = false
	end
	if consumed then
		display_update = 1
	end
	return consumed
end

-- clear patch pages whenever the stock page reset runs (mode keys)
if cpdlc_patch_reset_orig == nil then
	cpdlc_patch_reset_orig = reset_fmc_pages
	function reset_fmc_pages()
		cpdlc_patch_reset_orig()
		cpdlc_patch_clear()
	end
end
-- END CPDLC PATCH MODULE
