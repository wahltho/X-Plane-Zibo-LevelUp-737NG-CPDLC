-- BEGIN CPDLC PATCH AOC FREE TEXT MODULE
-- Additive extension kept separate from the 1.1.0 module so installed packages
-- can be upgraded structurally by both the standalone installer and the Toolkit.

cpdlc_patch_aoc_page = 0 -- 0 none, 1 compose, 2 verify
cpdlc_patch_aoc_target = ""
cpdlc_patch_aoc_text = { "", "", "", "" }
cpdlc_patch_aoc_status = ""

function cpdlc_patch_aoc_entry_is_fo()
	return fmc2_input_lag == 1 and fmc1_input_lag ~= 1
end

function cpdlc_patch_aoc_entry_get()
	if cpdlc_patch_aoc_entry_is_fo() then
		return entry2
	end
	return entry
end

function cpdlc_patch_aoc_entry_clear()
	if cpdlc_patch_aoc_entry_is_fo() then
		entry2 = ""
	else
		entry = ""
	end
end

function cpdlc_patch_aoc_target_valid(value)
	return value ~= nil and string.len(value) >= 1 and string.len(value) <= 24
		and string.find(value, "^[A-Z0-9%-]+$") ~= nil
end

function cpdlc_patch_aoc_text_valid(value)
	return value ~= nil and string.len(value) <= 24
end

function cpdlc_patch_aoc_message()
	local result = ""
	for index = 1, 4 do
		local value = cpdlc_patch_trim(cpdlc_patch_aoc_text[index])
		if value ~= "" then
			if result ~= "" then result = result .. " " end
			result = result .. value
		end
	end
	return result
end

function cpdlc_patch_aoc_ready()
	return cpdlc_patch_aoc_target_valid(cpdlc_patch_aoc_target)
		and cpdlc_patch_aoc_message() ~= ""
end

function cpdlc_patch_aoc_open()
	-- Keep the stock MISC page active so its datalink ownership/lifecycle remains
	-- in force while the extension replaces only the visible page and key map.
	page_dl_misc = 1
	cpdlc_patch_aoc_page = 1
	cpdlc_patch_aoc_status = ""
	act_page = 1
	display_update = 1
end

function cpdlc_patch_aoc_return_to_misc()
	cpdlc_patch_aoc_page = 0
	page_dl_misc = 1
	act_page = 1
	display_update = 1
end

function cpdlc_patch_aoc_reset()
	cpdlc_patch_aoc_page = 0
	cpdlc_patch_aoc_target = ""
	cpdlc_patch_aoc_text = { "", "", "", "" }
	cpdlc_patch_aoc_status = ""
end

function cpdlc_patch_aoc_draw_compose()
	max_page_buf = 1
	line0_l = "     AOC FREE TEXT      "
	line1_x = " TO                     "
	line1_l = "<" .. cpdlc_patch_aoc_target
	line2_x = " MESSAGE                "
	line2_l = "<" .. cpdlc_patch_aoc_text[1]
	line3_l = "<" .. cpdlc_patch_aoc_text[2]
	line4_l = "<" .. cpdlc_patch_aoc_text[3]
	line5_l = "<" .. cpdlc_patch_aoc_text[4]
	if cpdlc_patch_aoc_ready() then
		line6_l = cpdlc_patch_lr("<RETURN", "VERIFY>")
	else
		line6_l = "<RETURN                 "
	end
end

function cpdlc_patch_aoc_draw_verify()
	max_page_buf = 1
	line0_l = " AOC FREE TEXT VERIFY   "
	line1_x = " TO                     "
	line1_l = " " .. cpdlc_patch_aoc_target
	line2_x = " MESSAGE                "
	line2_l = " " .. cpdlc_patch_aoc_text[1]
	line3_l = " " .. cpdlc_patch_aoc_text[2]
	line4_l = " " .. cpdlc_patch_aoc_text[3]
	line5_l = " " .. cpdlc_patch_aoc_text[4]
	line6_l = cpdlc_patch_lr("<RETURN", "SEND>")
end

function cpdlc_patch_aoc_set_field(index)
	local value = cpdlc_patch_aoc_entry_get()
	if value == ">DELETE" then
		value = ""
	elseif value == "" then
		if index == 0 then
			value = cpdlc_patch_aoc_target
		else
			value = cpdlc_patch_aoc_text[index]
		end
		if cpdlc_patch_aoc_entry_is_fo() then entry2 = value else entry = value end
		return
	end
	local valid = cpdlc_patch_aoc_text_valid(value)
	if index == 0 then valid = cpdlc_patch_aoc_target_valid(value) end
	if not valid then
		add_fmc_msg(INVALID_INPUT, 0, 0)
		return
	end
	if index == 0 then
		cpdlc_patch_aoc_target = value
	else
		cpdlc_patch_aoc_text[index] = value
	end
	cpdlc_patch_aoc_entry_clear()
	cpdlc_patch_aoc_status = ""
end

function cpdlc_patch_aoc_lsk(key)
	if cpdlc_patch_aoc_page == 1 then
		if key == "6L" then
			cpdlc_patch_aoc_return_to_misc()
		elseif key == "6R" and cpdlc_patch_aoc_ready() then
			cpdlc_patch_aoc_page = 2
		elseif key == "1L" then
			cpdlc_patch_aoc_set_field(0)
		elseif key == "2L" then
			cpdlc_patch_aoc_set_field(1)
		elseif key == "3L" then
			cpdlc_patch_aoc_set_field(2)
		elseif key == "4L" then
			cpdlc_patch_aoc_set_field(3)
		elseif key == "5L" then
			cpdlc_patch_aoc_set_field(4)
		end
		return true
	elseif cpdlc_patch_aoc_page == 2 then
		if key == "6L" then
			cpdlc_patch_aoc_page = 1
		elseif key == "6R" then
			if not cpdlc_patch_aoc_ready() then
				cpdlc_patch_aoc_page = 1
				add_fmc_msg("REVERIFY", 0, 0)
			elseif HBDR_ready == 0 or HBDR_comm_ready == 0 then
				add_fmc_msg("NO COMM", 0, 0)
			else
				send_telex(cpdlc_patch_aoc_message(), cpdlc_patch_aoc_target)
				cpdlc_patch_aoc_target = ""
				cpdlc_patch_aoc_text = { "", "", "", "" }
				cpdlc_patch_aoc_status = "SENT"
				cpdlc_patch_aoc_return_to_misc()
			end
		end
		return true
	end
	return false
end

cpdlc_patch_aoc_overlay_orig = cpdlc_patch_overlay
function cpdlc_patch_overlay()
	if cpdlc_patch_aoc_page ~= 0 then
		null_fmc_disp()
		if cpdlc_patch_aoc_page == 1 then
			cpdlc_patch_aoc_draw_compose()
		else
			cpdlc_patch_aoc_draw_verify()
		end
		return
	end
	cpdlc_patch_aoc_overlay_orig()
	if page_dl_misc == 1 then
		line4_l = cpdlc_patch_lr("<PASSWORD", "FREE TEXT>")
		if cpdlc_patch_aoc_status ~= "" then
			line5_l = cpdlc_patch_lr("", cpdlc_patch_aoc_status)
		end
	end
end

cpdlc_patch_aoc_lsk_orig = cpdlc_patch_lsk
function cpdlc_patch_lsk(key)
	if cpdlc_patch_aoc_lsk(key) then
		display_update = 1
		return true
	end
	if page_dl_misc == 1 and key == "4R" then
		cpdlc_patch_aoc_open()
		return true
	end
	return cpdlc_patch_aoc_lsk_orig(key)
end

cpdlc_patch_aoc_clear_orig = cpdlc_patch_clear
function cpdlc_patch_clear()
	cpdlc_patch_aoc_clear_orig()
	cpdlc_patch_aoc_reset()
end
-- END CPDLC PATCH AOC FREE TEXT MODULE
