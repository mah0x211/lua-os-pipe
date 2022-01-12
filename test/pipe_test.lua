require('nosigpipe')
local pipe = require('pipe')
local testcase = require('testcase')

function testcase.create_pipe()
    -- test that create pipe.reader and pipe.writer
    local r, w, err = pipe()
    assert(not err, err)
    assert.match(tostring(r), '^pipe.reader:', false)
    assert.match(tostring(w), '^pipe.writer:', false)
end

function testcase.nonblock()
    local r, w, err = pipe()
    assert(not err, err)

    -- test that default false
    for _, v in ipairs({
        r,
        w,
    }) do
        assert.is_false(v:nonblock())
    end

    -- test that sets nonblock to true, and returns a previous state
    for _, bool in ipairs({
        true,
        false,
    }) do
        for _, v in ipairs({
            r,
            w,
        }) do
            if bool then
                assert.is_false(v:nonblock(true))
                assert.is_true(v:nonblock())
            else
                assert.is_true(v:nonblock(false))
                assert.is_false(v:nonblock())
            end
        end
    end

    -- test that throws error with invalid argument
    for _, v in ipairs({
        r,
        w,
    }) do
        err = assert.throws(function()
            v:nonblock('foo')
        end)
        assert.match(err, 'boolean expected, got string')
    end
end

function testcase.fd()
    local r, w, err = pipe()
    assert(not err, err)

    -- test that returns fd
    for _, v in ipairs({
        r,
        w,
    }) do
        assert.is_int(v:fd())
    end
end

function testcase.close()
    local r, w, err = pipe()
    assert(not err, err)

    -- test that close fd without error
    for _, v in ipairs({
        r,
        w,
    }) do
        assert(not v:close())
        assert.equal(v:fd(), -1)
    end

    -- test that can calls close after close
    for _, v in ipairs({
        r,
        w,
    }) do
        assert(not v:close())
    end
end

function testcase.read_write()
    local r, w, err = pipe()
    assert(not err, err)
    r:nonblock(true)
    w:nonblock(true)

    -- luacheck: ignore err
    -- luacheck: ignore again
    -- test that write data to writer
    local s = 'hello world!'
    local n, err, again = w:write(s)
    assert.equal(n, #s)
    assert(not err, err)
    assert(not again)

    -- test that read data from reader
    local data, err, again = r:read()
    assert.equal(data, s)
    assert(not err, err)
    assert(not again)

    -- test that returns `again=true` if the data has not arrived.
    data, err, again = r:read()
    assert(not data)
    assert(not err, err)
    assert.is_true(again)

    -- test that returns `again=true` when the buffer is full
    while 1 do
        n, err, again = w:write(s)
        if again then
            assert.equal(n, 0)
            assert(not err, err)
            assert.is_true(again)
            break
        end
    end

    -- test that throws error if data is not string
    err = assert.throws(function()
        w:write(true)
    end)
    assert.match(err, 'string expected, got boolean')

    -- test that returns error if read after closed
    for _, v in ipairs({
        r,
        w,
    }) do
        v:close()
        if v == r then
            data, err, again = r:read()
        else
            data, err, again = w:write('hello')
        end
        assert.is_nil(data)
        assert.match(err, 'Bad file')
        assert.is_nil(again)
    end

    -- test that returns all nil if write after closed by peer
    r, w = pipe()
    r:close()
    assert.empty({
        w:write('hello'),
    })
    w:close()

    -- test that returns all nil if read after closed by peer
    r, w = pipe()
    w:close()
    assert.empty({
        r:read(),
    })
    r:close()
end
