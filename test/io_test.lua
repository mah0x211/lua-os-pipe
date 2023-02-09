require('luacov')
local testcase = require('testcase')
local pipeio = require('pipe.io')
local gettime = require('clock').gettime
local errno = require('errno')

function testcase.new()
    -- test that create new pipe
    local p = assert(pipeio())
    assert.match(p, '^pipe%.io: ', false)

    -- test that create new pipe with nonblock option
    p = assert(pipeio(true))
    assert.match(p, '^pipe%.io: ', false)

    -- test that throws an error if nonblock argument is invalid
    local err = assert.throws(pipeio, {})
    assert.match(err, 'boolean expected,')
end

function testcase.read_write_nonblock()
    local p = assert(pipeio(true))

    -- test that return again=true if no data available
    local t = gettime()
    local s, err, again = p:read(nil, 50)
    t = gettime() - t
    assert.is_nil(s)
    assert.is_nil(err)
    assert.is_true(again)
    assert.greater_or_equal(t, 0.05)
    assert.less(t, 0.06)

    -- test that write message to pipe
    local msg = 'hello'
    local n = assert(p:write(msg))
    assert.equal(n, #msg)

    -- test that read message from pipe
    s = assert(p:read())
    assert.equal(s, msg)

    -- test that return again=true if no write buffer available
    while true do
        t = gettime()
        n, err, again = p:write(msg, 50)
        t = gettime() - t
        if n ~= #msg then
            assert.is_nil(err)
            assert.is_true(again)
            assert.greater_or_equal(t, 0.05)
            assert.less(t, 0.06)
            break
        end
    end
end

function testcase.closerd()
    local p = assert(pipeio())

    -- test that close reader
    assert.is_true(p:closerd())
    local _, err = p:read()
    assert.equal(err.type, errno.EBADF)

    -- test that close can be called twice
    assert.is_true(p:closerd())
end

function testcase.closewr()
    local p = assert(pipeio())

    -- test that close writer
    assert.is_true(p:closewr())
    local _, err = p:write('hello')
    assert.equal(err.type, errno.EBADF)

    -- test that close can be called twice
    assert.is_true(p:closewr())
end

function testcase.close()
    local p = assert(pipeio())

    -- test that close reader and writer
    assert.is_true(p:close())
    local _, err = p:read()
    assert.equal(err.type, errno.EBADF)
    _, err = p:write('hello')
    assert.equal(err.type, errno.EBADF)

    -- test that close can be called twice
    assert.is_true(p:close())
end
