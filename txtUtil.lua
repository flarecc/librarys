-- SPDX-FileCopyrightText: 2017 Daniel Ratcliffe
--
-- SPDX-License-Identifier: LicenseRef-CCPL

--- The @{textutils} API provides helpful utilities for formatting and
-- manipulating strings.
--
-- @module textutils
-- @since 1.2


local expect = dofile("rom/modules/main/cc/expect.lua")
local expect, field = expect.expect, expect.field



local g_tLuaKeywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

--- A version of the ipairs iterator which ignores metamethods
local function inext(tbl, i)
    i = (i or 0) + 1
    local v = rawget(tbl, i)
    if v == nil then return nil else return i, v end
end

local serialize_infinity = math.huge
local function serialize_impl(t, tracking, indent, opts)
    local sType = type(t)
    if sType == "table" then
        if tracking[t] ~= nil then
            if tracking[t] == false then
                error("Cannot serialize table with repeated entries", 0)
            else
                error("Cannot serialize table with recursive entries", 0)
            end
        end
        tracking[t] = true

        local result
        if next(t) == nil then
            -- Empty tables are simple
            result = "{}"
        else
            -- Other tables take more work
            local open, sub_indent, open_key, close_key, equal, comma = "{\n", indent .. "  ", "[ ", " ] = ", " = ", ",\n"
            if opts.compact then
                open, sub_indent, open_key, close_key, equal, comma = "{", "", "[", "]=", "=", ","
            end

            result = open
            local seen_keys = {}
            for k, v in inext, t do
                seen_keys[k] = true
                result = result .. sub_indent .. serialize_impl(v, tracking, sub_indent, opts) .. comma
            end
            for k, v in next, t do
                if not seen_keys[k] then
                    local sEntry
                    if type(k) == "string" and not g_tLuaKeywords[k] and string.match(k, "^[%a_][%a%d_]*$") then
                        sEntry = k .. equal .. serialize_impl(v, tracking, sub_indent, opts) .. comma
                    else
                        sEntry = open_key .. serialize_impl(k, tracking, sub_indent, opts) .. close_key .. serialize_impl(v, tracking, sub_indent, opts) .. comma
                    end
                    result = result .. sub_indent .. sEntry
                end
            end
            result = result .. indent .. "}"
        end

        if opts.allow_repetitions then
            tracking[t] = nil
        else
            tracking[t] = false
        end
        return result

    elseif sType == "string" then
        return string.format("%q", t)

    elseif sType == "number" then
        if t ~= t then --nan
            return "0/0"
        elseif t == serialize_infinity then
            return "1/0"
        elseif t == -serialize_infinity then
            return "-1/0"
        else
            return tostring(t)
        end

    elseif sType == "boolean" or sType == "nil" then
        return tostring(t)

    else
        error("Cannot serialize type " .. sType, 0)

    end
end

local txt = {}

--[[- Convert a Lua object into a textual representation, suitable for
saving in a file or pretty-printing.

@param t The object to serialise
@tparam { compact? = boolean, allow_repetitions? = boolean } opts Options for serialisation.
 - `compact`: Do not emit indentation and other whitespace between terms.
 - `allow_repetitions`: Relax the check for recursive tables, allowing them to appear multiple
   times (as long as tables do not appear inside themselves).

@treturn string The serialised representation
@throws If the object contains a value which cannot be
serialised. This includes functions and tables which appear multiple
times.
@see cc.pretty.pretty_print An alternative way to display a table, often more
suitable for pretty printing.
@since 1.3
@changed 1.97.0 Added `opts` argument.
@usage Serialise a basic table.

    textutils.serialise({ 1, 2, 3, a = 1, ["another key"] = { true } })

@usage Demonstrates some of the other options

    local tbl = { 1, 2, 3 }
    print(textutils.serialise({ tbl, tbl }, { allow_repetitions = true }))

    print(textutils.serialise(tbl, { compact = true }))
]]
function txt.serialize(t, opts)
    local tTracking = {}
    expect(2, opts, "table", "nil")

    if opts then
        field(opts, "compact", "boolean", "nil")
        field(opts, "allow_repetitions", "boolean", "nil")
    else
        opts = {}
    end
    return serialize_impl(t, tTracking, "", opts)
end

txt.serialise = txt.serialize -- GB version

--- Converts a serialised string back into a reassembled Lua object.
--
-- This is mainly used together with @{textutils.serialise}.
--
-- @tparam string s The serialised string to deserialise.
-- @return[1] The deserialised object
-- @treturn[2] nil If the object could not be deserialised.
-- @since 1.3
function txt.unserialize(s)
    expect(1, s, "string")
    local func = load("return " .. s, "unserialize", "t", {})
    if func then
        local ok, result = pcall(func)
        if ok then
            return result
        end
    end
    return nil
end

txt.unserialise = txt.unserialize -- GB version

function txt.formatTime(nTime, bTwentyFourHour)
    expect(1, nTime, "number")
    expect(2, bTwentyFourHour, "boolean", "nil")
    local sTOD = nil
    if not bTwentyFourHour then
        if nTime >= 12 then
            sTOD = "PM"
        else
            sTOD = "AM"
        end
        if nTime >= 13 then
            nTime = nTime - 12
        end
    end

    local nHour = math.floor(nTime)
    local nMinute = math.floor((nTime - nHour) * 60)
    if sTOD then
        return string.format("%d:%02d %s", nHour == 0 and 12 or nHour, nMinute, sTOD)
    else
        return string.format("%d:%02d", nHour, nMinute)
    end
end

local function tabulateCommon(bPaged, ...)
    local tAll = table.pack(...)
    for i = 1, tAll.n do
        expect(i, tAll[i], "number", "table")
    end

    local w, h = term.getSize()
    local nMaxLen = w / 8
    for n, t in ipairs(tAll) do
        if type(t) == "table" then
            for nu, sItem in pairs(t) do
                local ty = type(sItem)
                if ty ~= "string" and ty ~= "number" then
                    error("bad argument #" .. n .. "." .. nu .. " (string expected, got " .. ty .. ")", 3)
                end
                nMaxLen = math.max(#tostring(sItem) + 1, nMaxLen)
            end
        end
    end
    local nCols = math.floor(w / nMaxLen)
    local nLines = 0
    local function newLine()
        if bPaged and nLines >= h - 3 then
            pagedPrint()
        else
            print()
        end
        nLines = nLines + 1
    end

    local function drawCols(_t)
        local nCol = 1
        for _, s in ipairs(_t) do
            if nCol > nCols then
                nCol = 1
                newLine()
            end

            local cx, cy = term.getCursorPos()
            cx = 1 + (nCol - 1) * nMaxLen
            term.setCursorPos(cx, cy)
            term.write(s)

            nCol = nCol + 1
        end
        print()
    end

    local previous_colour = term.getTextColour()
    for _, t in ipairs(tAll) do
        if type(t) == "table" then
            if #t > 0 then
                drawCols(t)
            end
        elseif type(t) == "number" then
            term.setTextColor(t)
        end
    end
    term.setTextColor(previous_colour)
end

--[[- Prints tables in a structured form.

This accepts multiple arguments, either a table or a number. When
encountering a table, this will be treated as a table row, with each column
width being auto-adjusted.

When encountering a number, this sets the text color of the subsequent rows to it.

@tparam {string...}|number ... The rows and text colors to display.
@since 1.3
@usage

    textutils.tabulate(
      colors.orange, { "1", "2", "3" },
      colors.lightBlue, { "A", "B", "C" }
    )
]]
function txt.tabulate(...)
    return tabulateCommon(false, ...)
end

--[[- Prints tables in a structured form, stopping and prompting for input should
the result not fit on the terminal.

This functions identically to @{textutils.tabulate}, but will prompt for user
input should the whole output not fit on the display.

@tparam {string...}|number ... The rows and text colors to display.
@see textutils.tabulate
@see textutils.pagedPrint
@since 1.3

@usage Generates a long table, tabulates it, and prints it to the screen.

    local rows = {}
    for i = 1, 30 do rows[i] = {("Row #%d"):format(i), math.random(1, 400)} end

    textutils.pagedTabulate(colors.orange, {"Column", "Value"}, colors.lightBlue, table.unpack(rows))
]]
function txt.pagedTabulate(...)
    return tabulateCommon(true, ...)
end

return txt