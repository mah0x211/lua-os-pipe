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
local type = type

--- @class os.pipe.reader
--- @field fd fun(self:os.pipe.reader):integer
--- @field nonblock fun(self:os.pipe.reader, nonblock:boolean?):(ok: boolean, err: any)
--- @field close fun(self:os.pipe.reader):(ok: boolean, err: any)
--- @field read fun(self:os.pipe.reader, bufsize: integer?):(s: string?, err: any, again: boolean)
--- @class os.pipe.writer
--- @field fd fun(self:os.pipe.writer):integer
--- @field nonblock fun(self:os.pipe.writer, nonblock:boolean):(ok: boolean, err: any)
--- @field close fun(self:os.pipe.writer):(ok: boolean, err: any)
--- @field write fun(self:os.pipe.writer, s: string):(len: integer?, err: any, again: boolean)

--- @type fun(nonblock: boolean):(r: os.pipe.reader, w:os.pipe.writer, err:any)
local pipe = require('os.pipe')
local io_wait_readable = require('io.wait').readable
local io_wait_writable = require('io.wait').writable
local pollable = require('gpoll').pollable
local poll_wait_readable = require('gpoll').wait_readable
local poll_wait_writable = require('gpoll').wait_writable
local poll_unwait_readable = require('gpoll').unwait_readable
local poll_unwait_writable = require('gpoll').unwait_writable

--- @class time.clock.deadline
--- @field time fun(self:time.clock.deadline):number
--- @field remain fun(self:time.clock.deadline):number

--- @type fun(duration: number):(time.clock.deadline, number)
local new_deadline = require('time.clock.deadline').new

local INF_POS = math.huge
local INF_NEG = -INF_POS

--- is_finite returns true if x is finite number
--- @param x number
--- @return boolean
local function is_finite(x)
    return type(x) == 'number' and (x < INF_POS and x >= INF_NEG)
end

--- @class pipe.io
--- @field reader os.pipe.reader
--- @field writer os.pipe.writer
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
--- @param sec? number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function PipeIO:wait_readable(sec)
    if pollable() then
        return poll_wait_readable(self.reader:fd(), sec)
    end
    return io_wait_readable(self.reader:fd(), sec)
end

--- unwait_readable
--- @private
function PipeIO:unwait_readable()
    if pollable() then
        poll_unwait_readable(self.reader:fd())
    end
end

--- wait_writable
--- @private
--- @param sec? number
--- @return boolean ok
--- @return any err
--- @return boolean? timeout
function PipeIO:wait_writable(sec)
    if pollable() then
        return poll_wait_writable(self.writer:fd(), sec)
    end
    return io_wait_writable(self.writer:fd(), sec)
end

--- unwait_writable
--- @private
function PipeIO:unwait_writable()
    if pollable() then
        poll_unwait_writable(self.writer:fd())
    end
end

--- read
--- @param bufsize? integer
--- @param sec? number
--- @return string str
--- @return any err
--- @return boolean? timeout
function PipeIO:read(bufsize, sec)
    assert(sec == nil or is_finite(sec), 'sec must be finite number or nil')

    local deadline = sec and new_deadline(sec)
    local str, err, again = self.reader:read(bufsize)
    if not again then
        return str, err
    end

    local reader = self.reader
    local ok, timeout

    repeat
        if deadline then
            sec = deadline:remain()
            if sec == 0 then
                return str, nil, true
            end
        end

        -- wait until readable
        ok, err, timeout = self:wait_readable(sec)
        if ok then
            str, err, again = reader:read()
        end
    until not again or timeout

    return str, err, timeout
end

--- write
--- @param str string
--- @param sec? number
--- @return integer len
--- @return any err
--- @return boolean? timeout
function PipeIO:write(str, sec)
    assert(sec == nil or is_finite(sec), 'sec must be finite number or nil')

    local deadline = sec and new_deadline(sec)
    local len, err, again = self.writer:write(str)
    if not again then
        return len, err
    end

    local writer = self.writer
    local total = 0
    local ok, timeout
    while true do
        total = total + len
        -- eliminate write data
        if len > 0 then
            str = sub(str, len + 1)
        end

        if deadline then
            sec = deadline:remain()
            if sec == 0 then
                return total, nil, true
            end
        end

        -- wait until writable
        ok, err, timeout = self:wait_writable(sec)
        if not ok then
            return total, err, timeout
        end

        len, err, again = writer:write(str)
        if not again then
            return len and total + len, err
        end
    end
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
