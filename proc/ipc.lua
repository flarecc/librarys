---@module "sync"
local sync = loadfile("/lib/sync.lua",_ENV)()
---@module ipc
local ipc = {}
ipc.signal={SIGHUP=1,SIGINT=2,SIGQUIT=3,SIGTRAP=5,SIGABRT=6,SIGKILL=9,SIGPIPE=13,SIGTERM=15,SIGCONT=18,SIGSTOP=19,SIGTTIN=21,SIGTTOU=22}

function ipc:register(name)
    kernel.procIPCReg(name)
    local q = sync:queue()
    local com = {}
    function com:recv()
        local d = q:pull()
        local req = {data = d.data,pid=d.pid}
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
        q:push({lock=lock,data={...},pid=kernel.getPID()})
        kernel.signalProc(pid,ipc.signal.SIGINT)
        return lock:wait()
    end
    return com
end

return ipc