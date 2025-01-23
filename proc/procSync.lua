---@module sync
local sync = {}

function sync:queue()
    if not kernel.procHasQueue() then
        local q = kernel.procNewQueue()
        local queue = {}
        function queue:pull()
            while #q == 0 do
                coroutine.yield()
            end
            return table.remove(q, 1)
        end
        function queue:push(data)
            table.insert(q,data)
        end
        return queue
    end
end
function sync:fetchQueue(pid)
    local q = kernel.procGetQueue(pid)
    if q ==nil then
        error("no queue")
    end
    local queue = {}
    function queue:pull()
        while #q == 0 do
            coroutine.yield()
        end
        return table.remove(q, 1)
    end
    function queue:push(data)
        table.insert(q,data)
    end
    return queue
end
function sync:lock()
    local lock = {locked=false,by=kernel.getPID()}
    function lock:lock()
        self.locked = true
        self.by=kernel.getPID()
    end
    function lock:remote_lock(pid)
        self.locked = true
        self.by=pid
    end
    function lock:unlock()
        if self.by==kernel.getPID() then
            self.locked = false
        else
            while self.locked do
                coroutine.yield()
            end
        end
    end
    return lock
end
function sync:pipe()
    local pipe = {data=nil}
    local lock = self:lock()
    function pipe:lock()
        lock:lock()
    end
    function pipe:remote_lock(pid)
        lock:remote_lock(pid)
    end
    function pipe:unlock(data)
       lock:unlock()
       self.data =data
    end
    function pipe:wait()
        lock:unlock()
        return self.data
    end
    return pipe
end
return sync