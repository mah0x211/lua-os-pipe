--
-- Copyright (C) 2023 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local sub = string.sub
local pipe = require('os.pipe')
local poll = require('gpoll')
local pollable = poll.pollable
local new_readable_event = poll.new_readable_event
local new_writable_event = poll.new_writable_event
local dispose_event = poll.dispose_event
local wait_event = poll.wait_event
local iowait = require('io.wait')
local iowait_readable = iowait.readable
local iowait_writable = iowait.writable

--- @class pipe.io
--- @field reader pipe.reader
--- @field writer pipe.writer
--- @field readable_evid any
--- @field writable_evid any
local PipeIO = {}

--- init
--- @params nonblock boolean
--- @return pipe.io? pipe
--- @return any err
function PipeIO:init(nonblock)
    local reader, writer, err = pipe(nonblock)
    if err then
        return nil, err
    end

    self.reader = reader
    self.writer = writer
    return self
end

--- wait_readable
--- @private
--- @param msec? integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function PipeIO:wait_readable(msec)
    local evid = self.readable_evid
    if not evid then
        if not pollable() then
            return iowait_readable(self.reader:fd(), msec)
        end

        local err
        evid, err = new_readable_event(self.reader:fd())
        if not evid then
            return false, err
        end
        self.readable_evid = evid
    end

    -- wait until readable
    return wait_event(evid, msec)
end

--- unwait_readable
--- @private
function PipeIO:unwait_readable()
    if self.readable_evid then
        dispose_event(self.readable_evid)
        self.readable_evid = nil
    end
end

--- wait_writable
--- @private
--- @param msec? integer
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function PipeIO:wait_writable(msec)
    local evid = self.writable_evid
    if not evid then
        if not pollable() then
            return iowait_writable(self.writer:fd(), msec)
        end

        local err
        evid, err = new_writable_event(self.writer:fd())
        if not evid then
            return false, err
        end
        self.writable_evid = evid
    end

    -- wait until writable
    return wait_event(evid, msec)
end

--- unwait_writable
--- @private
function PipeIO:unwait_writable()
    if self.writable_evid then
        dispose_event(self.writable_evid)
        self.writable_evid = nil
    end
end

--- read
--- @param bufsize? integer
--- @param msec? integer
--- @return string str
--- @return any err
--- @return boolean? timeout
function PipeIO:read(bufsize, msec)
    local str, err, again = self.reader:read(bufsize)
    if not again then
        return str, err
    end

    local reader = self.reader
    local ok, timeout
    repeat
        -- wait until readable
        ok, err, timeout = self:wait_readable(msec)
        if ok then
            str, err, again = reader:read()
        end
    until not again or timeout

    return str, err, timeout
end

--- write
--- @param str string
--- @param msec? integer
--- @return integer len
--- @return any err
--- @return boolean? timeout
function PipeIO:write(str, msec)
    local len, err, again = self.writer:write(str)
    if not again then
        return len, err
    end

    local writer = self.writer
    local total = 0
    local ok, timeout
    repeat
        total = total + len
        -- eliminate write data
        if len > 0 then
            str = sub(str, len + 1)
        end

        -- wait until writable
        ok, err, timeout = self:wait_writable(msec)
        if ok then
            len, err, again = writer:write(str)
        end
    until not again or timeout

    return len and total + len, err, timeout
end

--- closerd
--- @return boolean ok
--- @return any err
function PipeIO:closerd()
    local fd = self.reader:fd()
    if fd == -1 then
        return true
    end
    self:unwait_readable()
    return self.reader:close()
end

--- closewr
--- @return boolean ok
--- @return any err
function PipeIO:closewr()
    local fd = self.writer:fd()
    if fd == -1 then
        return true
    end
    self:unwait_writable()
    return self.writer:close()
end

--- close
--- @return boolean ok
--- @return any err
function PipeIO:close()
    local rdok, rderr = self:closerd()
    local wrok, wrerr = self:closewr()
    if rdok then
        return wrok, wrerr
    end
    return rdok, rderr
end

PipeIO = require('metamodule').new(PipeIO)
return PipeIO

