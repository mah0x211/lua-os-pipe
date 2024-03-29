local testcase = require('testcase')
local errno = require('errno')
local pipe = require('os.pipe')

function testcase.create_pipe()
    -- test that create pipe.reader and pipe.writer
    local r, w, err = pipe()
    assert.is_nil(err)
    assert.match(tostring(r), '^os%.pipe%.reader:', false)
    assert.match(tostring(w), '^os%.pipe%.writer:', false)
end

function testcase.nonblock()
    local r, w, err = pipe()
    assert.is_nil(err)

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
    assert.is_nil(err)

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
    assert.is_nil(err)

    -- test that close fd without error
    for _, v in ipairs({
        r,
        w,
    }) do
        assert(v:close())
        assert.equal(v:fd(), -1)
    end

    -- test that can calls close after close
    for _, v in ipairs({
        r,
        w,
    }) do
        assert(v:close())
    end
end

function testcase.read_write()
    local r, w, err = pipe(true)
    assert.is_nil(err)
    assert.is_true(r:nonblock())
    assert.is_true(w:nonblock())

    -- test that write data to writer
    local s = 'hello world!'
    local n, again
    n, err, again = assert(w:write(s))
    assert.equal(n, #s)
    assert.is_nil(err)
    assert.is_nil(again)

    -- test that return EINVAL if empty-string
    n, err, again = w:write('')
    assert.is_nil(n)
    assert.equal(err.type, errno.EINVAL)
    assert.is_nil(again)

    -- test that read data from reader
    local data
    data, err, again = assert(r:read())
    assert.equal(data, s)
    assert.is_nil(err)
    assert.is_nil(again)

    -- test that returns EINVAL error if bufsize is less than 1
    data, err, again = r:read(0)
    assert.is_nil(data)
    assert.equal(err.type, errno.EINVAL)
    assert.is_nil(again)

    -- test that returns `again=true` if the data has not arrived.
    data, err, again = r:read()
    assert.is_nil(data)
    assert.is_nil(err)
    assert.is_true(again)

    -- test that returns `again=true` when the buffer is full
    while 1 do
        n, err, again = w:write(s)
        if again then
            assert.equal(n, 0)
            assert.is_nil(err)
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
        assert.equal(err.type, errno.EBADF)
        assert.is_nil(again)
    end

    -- test that returns EPIPE error if write after closed by peer
    r, w = pipe()
    r:close()
    n, err, again = w:write('hello')
    assert.is_nil(n)
    assert.equal(err.type, errno.EPIPE)
    assert.is_nil(again)
    w:close()

    -- test that returns all nil if read after closed by peer
    r, w = pipe()
    w:close()
    assert.empty({
        r:read(),
    })
    r:close()
end
