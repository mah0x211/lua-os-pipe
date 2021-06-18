package = "pipe"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-pipe.git"
}
description = {
    summary = "create descriptor pair for interprocess communication.",
    homepage = "https://github.com/mah0x211/lua-pipe",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        pipe = {
            sources = { "src/pipe.c" }
        },
    }
}
