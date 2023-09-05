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
local io_wait_readable = require('io.wait').readable
local io_wait_writable = require('io.wait').writable
local pollable = require('gpoll').pollable
local poll_wait_readable = require('gpoll').wait_readable
local poll_wait_writable = require('gpoll').wait_writable
local poll_unwait_readable = require('gpoll').unwait_readable
local poll_unwait_writable = require('gpoll').unwait_writable

--- @class pipe.io
--- @field reader pipe.reader
--- @field writer pipe.writer
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
    local str, err, again = self.reader:read(bufsize)
    if not again then
        return str, err
    end

    local reader = self.reader
    local ok, timeout
    repeat
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
        ok, err, timeout = self:wait_writable(sec)
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

