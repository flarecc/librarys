-- SPDX-FileCopyrightText: 2017 Daniel Ratcliffe
--
-- SPDX-License-Identifier: LicenseRef-CCPL

--- The Terminal API provides functions for writing text to the terminal and
-- monitors, and drawing ASCII graphics.
--
-- @module term

local expect = dofile("rom/modules/main/cc/expect.lua").expect

local native =term
local redirectTarget = native

local function wrap(_sFunction)
    return function(...)
        return redirectTarget[_sFunction](...)
    end
end

local t = {}

--- Redirects terminal output to a monitor, a @{window}, or any other custom
-- terminal object. Once the redirect is performed, any calls to a "term"
-- function - or to a function that makes use of a term function, as @{print} -
-- will instead operate with the new terminal object.
--
-- A "terminal object" is simply a table that contains functions with the same
-- names - and general features - as those found in the term table. For example,
-- a wrapped monitor is suitable.
--
-- The redirect can be undone by pointing back to the previous terminal object
-- (which this function returns whenever you switch).
--
-- @tparam Redirect target The terminal redirect the @{term} API will draw to.
-- @treturn Redirect The previous redirect object, as returned by
-- @{term.current}.
-- @since 1.31
-- @usage
-- Redirect to a monitor on the right of the computer.
--     term.redirect(peripheral.wrap("right"))
t.redirect = function(target)
    expect(1, target, "table")
    

    for _, method in ipairs {
        "setGraphicsMode",
        "getGraphicsMode",
        "setPixel",
        "getPixel",
        "drawPixels",
        "getPixels",
        "showMouse",
        "relativeMouse",
        "setFrozen",
        "getFrozen"
    } do
        if target[method] == nil then
            target[method] = native[method]
        end
    end

    for k, v in pairs(native) do
        if type(k) == "string" and type(v) == "function" then
            if type(target[k]) ~= "function" then
                target[k] = function()
                    error("Redirect object is missing method " .. k .. ".", 2)
                end
            end
        end
    end
    local oldRedirectTarget = redirectTarget
    redirectTarget = target
    return oldRedirectTarget
end

--- Returns the current terminal object of the computer.
--
-- @treturn Redirect The current terminal redirect
-- @since 1.6
-- @usage
-- Create a new @{window} which draws to the current redirect target
--     window.create(term.current(), 1, 1, 10, 10)
t.current = function()
    return redirectTarget
end

--- Get the native terminal object of the current computer.
--
-- It is recommended you do not use this function unless you absolutely have
-- to. In a multitasked environment, @{term.native} will _not_ be the current
-- terminal object, and so drawing may interfere with other programs.
--
-- @treturn Redirect The native terminal redirect.
-- @since 1.6
t.native = function()
    return native
end

-- Some methods shouldn't go through redirects, so we move them to the main
-- term API.
for _, method in ipairs { "nativePaletteColor", "nativePaletteColour", "screenshot" } do
    t[method] = native[method]
    native[method] = nil
end

for k, v in pairs(native) do
    if type(k) == "string" and type(v) == "function" then
        t[k] = wrap(k)
    end
end
return t