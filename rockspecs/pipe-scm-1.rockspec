package = "pipe"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-pipe.git",
}
description = {
    summary = "create descriptor pair for interprocess communication.",
    homepage = "https://github.com/mah0x211/lua-pipe",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "errno >= 0.3.0",
}
build = {
    type = "make",
    build_variables = {
        PACKAGE = "pipe",
        SRCDIR = "src",
        CFLAGS = "$(CFLAGS)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        PIPE_COVERAGE = "$(PIPE_COVERAGE)",
    },
    install_variables = {
        PACKAGE = "pipe",
        SRCDIR = "src",
        INST_LIBDIR = "$(LIBDIR)",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
    },
}
