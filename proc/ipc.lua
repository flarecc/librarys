---@module "sync"
local sync = loadfile("/lib/sync.lua")()

---@module ipc
local ipc = {}
function ipc:register(name)
    kernel.procIPCReg(name)
    local q = sync:queue()
    local com = {}
    function com:recv()
        local d = q:pull()
        local req = {data = d.data}
        function req:respond(data)
            d.lock:unlock(data)
        end
        function req:getData()
            return table.unpack(self.data)
        end
        return req
    end
    return com
end

function ipc:lookup(name)
    local pid = kernel.procIPCLookup(name)
    local q = sync:fetchQueue(pid)
    local com = {}
    function com:request(...)
        local lock = sync:pipe()
        lock:remote_lock(pid)
        q:push({lock=lock,data={...}})
        return lock:wait()
    end
    return com
end

return ipc