/**
 *  Copyright (C) 2021 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to
 *  deal in the Software without restriction, including without limitation the
 *  rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
// lua
#include <lauxlib.h>
#include <lua_errno.h>

#define PIPE_READER_MT "os.pipe.reader"
#define PIPE_WRITER_MT "os.pipe.writer"

#define DEFAULT_RECVSIZE 4096

typedef struct {
    int fd;
} pipe_fd_t;

static int write_lua(lua_State *L)
{
    pipe_fd_t *p    = luaL_checkudata(L, 1, PIPE_WRITER_MT);
    size_t len      = 0;
    const char *buf = lauxh_checklstring(L, 2, &len);
    ssize_t rv      = 0;

    // invalid length
    if (!len) {
        lua_pushnil(L);
        errno = EINVAL;
        lua_errno_new(L, errno, "write");
        return 2;
    }

    rv = write(p->fd, buf, len);
    switch (rv) {
    // got error
    case -1:
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
            // again
            lua_pushinteger(L, 0);
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        }
        // got error
        // closed by peer: EPIPE
        lua_pushnil(L);
        lua_errno_new(L, errno, "write");
        return 2;

    default:
        lua_pushinteger(L, rv);
        if (len - (size_t)rv) {
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        }
        return 1;
    }
}

static int read_lua(lua_State *L)
{
    pipe_fd_t *p    = luaL_checkudata(L, 1, PIPE_READER_MT);
    lua_Integer len = lauxh_optinteger(L, 2, DEFAULT_RECVSIZE);
    char *buf       = NULL;
    ssize_t rv      = 0;

    // invalid length
    if (len <= 0) {
        lua_pushnil(L);
        errno = EINVAL;
        lua_errno_new(L, errno, "read_lua");
        return 2;
    }

    buf = lua_newuserdata(L, len);
    rv  = read(p->fd, buf, (size_t)len);
    switch (rv) {
    case 0:
        // close by peer
        return 0;

    case -1:
        // got error
        lua_pushnil(L);
        // again
        if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        }
        // got error
        lua_errno_new(L, errno, "read");
        return 2;

    default:
        lua_pushlstring(L, buf, rv);
        return 1;
    }
}

static inline int close_lua(lua_State *L, const char *tname)
{
    pipe_fd_t *p = luaL_checkudata(L, 1, tname);
    int fd       = p->fd;

    if (fd == -1) {
        lua_pushboolean(L, 1);
        return 1;
    }
    p->fd = -1;

    if (close(fd) == 0) {
        lua_pushboolean(L, 1);
        return 1;
    }
    // got error
    lua_pushboolean(L, 0);
    lua_errno_new(L, errno, "close");
    return 2;
}

static int close_writer_lua(lua_State *L)
{
    return close_lua(L, PIPE_WRITER_MT);
}

static int close_reader_lua(lua_State *L)
{
    return close_lua(L, PIPE_READER_MT);
}

static inline int fd_lua(lua_State *L, const char *tname)
{
    pipe_fd_t *p = luaL_checkudata(L, 1, tname);

    lua_pushinteger(L, p->fd);
    return 1;
}

static int fd_writer_lua(lua_State *L)
{
    return fd_lua(L, PIPE_WRITER_MT);
}

static int fd_reader_lua(lua_State *L)
{
    return fd_lua(L, PIPE_READER_MT);
}

static inline int optboolean(lua_State *L, int idx, int def)
{
    if (lua_gettop(L) < idx) {
        return def;
    }
    luaL_checktype(L, idx, LUA_TBOOLEAN);
    return lua_toboolean(L, idx);
}

static inline int nonblock_lua(lua_State *L, const char *tname)
{
    pipe_fd_t *p = luaL_checkudata(L, 1, tname);
    int enabled  = optboolean(L, 2, -1);
    int flg      = fcntl(p->fd, F_GETFL, 0);

    // got
    if (flg != -1) {
        int newflg = flg;

        if (enabled == 1) {
            newflg = flg | O_NONBLOCK;
        } else if (enabled == 0) {
            newflg = flg & ~O_NONBLOCK;
        }

        if (newflg == flg || fcntl(p->fd, F_SETFL, newflg) == 0) {
            // returns whether the O_NONBLOCK flag is enabled or not.
            lua_pushboolean(L, flg & O_NONBLOCK);
            return 1;
        }
    }

    // got error
    lua_pushnil(L);
    lua_errno_new(L, errno, "fcntl");
    return 2;
}

static int nonblock_writer_lua(lua_State *L)
{
    return nonblock_lua(L, PIPE_WRITER_MT);
}

static int nonblock_reader_lua(lua_State *L)
{
    return nonblock_lua(L, PIPE_READER_MT);
}

static inline int tostring_lua(lua_State *L, const char *tname)
{
    lua_pushfstring(L, "%s: %p", tname, lua_touserdata(L, 1));
    return 1;
}

static int tostring_writer_lua(lua_State *L)
{
    return tostring_lua(L, PIPE_WRITER_MT);
}

static int tostring_reader_lua(lua_State *L)
{
    return tostring_lua(L, PIPE_READER_MT);
}

static int gc_lua(lua_State *L)
{
    pipe_fd_t *p = lua_touserdata(L, 1);

    if (p->fd != -1) {
        close(p->fd);
    }

    return 0;
}

static inline int set_nonblock(int fds[2])
{
    int flg0 = fcntl(fds[0], F_GETFL, 0);
    int flg1 = fcntl(fds[1], F_GETFL, 0);

    return flg0 == -1 || flg1 == -1 ||
           fcntl(fds[0], F_SETFL, flg0 | O_NONBLOCK) ||
           fcntl(fds[1], F_SETFL, flg1 | O_NONBLOCK);
}

static inline int set_cloexec(int fds[2])
{
    return fcntl(fds[0], F_SETFD, FD_CLOEXEC) ||
           fcntl(fds[1], F_SETFD, FD_CLOEXEC);
}

static int new_lua(lua_State *L)
{
    int nonblock      = lauxh_optboolean(L, 1, 0);
    pipe_fd_t *reader = lua_newuserdata(L, sizeof(pipe_fd_t));
    pipe_fd_t *writer = lua_newuserdata(L, sizeof(pipe_fd_t));
    int fds[2];

    if (pipe(fds) == 0) {
        if (set_cloexec(fds) == 0 &&
            (nonblock == 0 || set_nonblock(fds) == 0)) {
            *reader = (pipe_fd_t){fds[0]};
            *writer = (pipe_fd_t){fds[1]};
            luaL_getmetatable(L, PIPE_READER_MT);
            lua_setmetatable(L, -3);
            luaL_getmetatable(L, PIPE_WRITER_MT);
            lua_setmetatable(L, -2);
            return 2;
        }

        close(fds[0]);
        close(fds[1]);
    }

    // got error
    lua_pushnil(L);
    lua_pushnil(L);
    lua_errno_new(L, errno, "pipe");
    return 3;
}

static inline void createmt(lua_State *L, const char *tname,
                            struct luaL_Reg *mmethods, struct luaL_Reg *methods)
{
    struct luaL_Reg *ptr = mmethods;

    // create new metatable of tname already exists
    luaL_newmetatable(L, tname);
    // push metamethods
    while (ptr->name) {
        lauxh_pushfn2tbl(L, ptr->name, ptr->func);
        ptr++;
    }
    // push methods
    ptr = methods;
    lua_pushstring(L, "__index");
    lua_newtable(L);
    while (ptr->name) {
        lauxh_pushfn2tbl(L, ptr->name, ptr->func);
        ptr++;
    }
    lua_rawset(L, -3);
    lua_pop(L, 1);
}

LUALIB_API int luaopen_os_pipe(lua_State *L)
{
    struct luaL_Reg reader_mmethods[] = {
        {"__gc",       gc_lua             },
        {"__tostring", tostring_reader_lua},
        {NULL,         NULL               }
    };
    struct luaL_Reg reader_methods[] = {
        {"nonblock", nonblock_reader_lua},
        {"fd",       fd_reader_lua      },
        {"close",    close_reader_lua   },
        {"read",     read_lua           },
        {NULL,       NULL               }
    };
    struct luaL_Reg writer_mmethods[] = {
        {"__gc",       gc_lua             },
        {"__tostring", tostring_writer_lua},
        {NULL,         NULL               }
    };
    struct luaL_Reg writer_methods[] = {
        {"nonblock", nonblock_writer_lua},
        {"fd",       fd_writer_lua      },
        {"close",    close_writer_lua   },
        {"write",    write_lua          },
        {NULL,       NULL               }
    };

    lua_errno_loadlib(L);

    createmt(L, PIPE_READER_MT, reader_mmethods, reader_methods);
    createmt(L, PIPE_WRITER_MT, writer_mmethods, writer_methods);
    lua_pushcfunction(L, new_lua);

    return 1;
}
