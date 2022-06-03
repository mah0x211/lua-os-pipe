# lua-pipe

[![test](https://github.com/mah0x211/lua-pipe/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-pipe/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-pipe/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-pipe)

create descriptor pair for interprocess communication.


## Installation

```bash
$ luarocks install mah0x211/pipe
```

## Error Handling

the functions/methods are return the error object created by https://github.com/mah0x211/lua-errno module.


## Creating pipe reader and writer

### r, w, err = pipe( [nonblock] )

create instance of pipe reader and writer.

**Parameters**

- `nonblock:boolean`: set `O_NONBLOCK` flag to each descriptor.

**Returns**

- `r:pipe.reader`: instance of [pipe.reader](#pipe.reader-instance-methods).
- `w:pipe.writer`: instance of [pipe.writer](#pipe.writer-instance-methods).
- `err:error`: error object.


## Common methods

`pipe.reader` and `pipe.writer` instances have the following common methods.


### enabled, err = p:nonblock( [enabled] ) 

gets or sets the `O_NONBLOCK` flag.
if an error occurs, return `nil` and `err`.

**Parameters**

- `enabled:boolean`: set `O_NONBLOCK` flag to enabled.

**Returns**

- `enabled:boolean`: if `enabled` parameter passed, its returns a previous status.
- `err:error`: error object.


### fd = p:fd()

get the file descriptor.

**Returns**

- `fd:integer`: file descriptor. returns `-1` after `p:close()` is called.


### err = p:close()

close the associated descriptor.

**Returns**

- `err:error`: error object.


## `pipe.writer` methods

`pipe.writer` instances has the following methods.


### n, err, again = p:write( s )

write a string to the associated descriptor.

**Parameters**

- `s:string`: string data.

**Returns**

- `n:integer`: number of bytes written.
- `err:error`: error object.
- `again:boolean`: `nil`, or `true` if `errno` is `EAGAIN`, `EWOULDBLOCK` or `EINTR`.

**NOTE**

`write` syscall may raise the `SIGPIPE` signal. use the [nosigpipe](https://github.com/mah0x211/lua-nosigpipe) module or something similar to prevent this signal from killing the process.


**Usage**

```lua
require('nosigpipe')
-- you must install the nosigpipe module with `luarocks install nosigpipe`
-- to prevent SIGPIPE signals.
local dump = require('dump')
-- you must install dump module with `luarocks install dump`
local pipe = require('pipe')
local r, w, err = pipe(true)
assert(err == nil, err)

-- write a message
local n, err, again = w:write('hello')
print(dump({n, err, again}))
--[[ following string will be displayed.
{
    [1] = 5
}
]]

-- write a message until an again becomes true
repeat
    n, err, again = w:write('hello')
    assert(err == nil, err)
until again == true


-- write returns nil after reader is closed
r:close()
n, err, again = w:write('hello')
print(dump({n, err, again}))
--[[ following string will be displayed.
{}
]]

-- write returns err after writer is closed
w:close()
n, err, again = w:write('hello')
print(dump({n, err, again}))
--[[ following string will be displayed.
{
    [2] = "Bad file descriptor"
}
]]
```


## `pipe.reader` methods

`pipe.reader` instances has the following methods.


### s, err, again = p:read( [bufsize] )

read bytes of data from the associated descriptor.

Parameters

- `bufsize:integer`: number of bytes read (`default: 4096`).

**Returns**

- `s:string`: data read from associated descriptor, or `nil` if `read` syscall returned `0` or an error occurred.
- `err:error`: error object.
- `again:boolean`: nil or `true` if `errno` is `EAGAIN`, `EWOULDBLOCK` or `EINTR`.

NOTE: all return values will be `nil` if the number of bytes read is `0`.


**Usage**

```lua
require('nosigpipe')
-- you must install the nosigpipe module with `luarocks install nosigpipe`
-- to prevent SIGPIPE signals.
local dump = require('dump')
-- you must install dump module with `luarocks install dump`
local pipe = require('pipe')
local r, w, err = pipe(true)
assert(err == nil, err)

-- read returns again (true)
local s, err, again = r:read()
print(dump({s, err, again}))
--[[ following string will be displayed.
{
    [3] = true
}
]]

-- read a message from writer
w:write('hello')
s, err, again = r:read()
print(dump({s, err, again}))
--[[ following string will be displayed.
{
    [1] = "hello"
}
]]


-- read a buffered message even writer is closed
w:write('world!')
w:close()
s, err, again = r:read()
print(dump({s, err, again}))
--[[ following string will be displayed.
{
    [1] = "world!"
}
]]


-- read returns nil after writer is closed
s, err, again = r:read()
print(dump({s, err, again}))
--[[ following string will be displayed.
{}
]]


-- read returns err after reader is closed
r:close()
s, err, again = r:read()
print(dump({s, err, again}))
--[[ following string will be displayed.
{
    [2] = "./example.lua:65: in main chunk: [EBADF:9][read] Bad file descriptor"
}
]]

```
