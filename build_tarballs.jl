# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "MySQLBuilder"
version = v"0.21.0"

# Collection of sources required to build MySQLBuilder
sources = [
    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-linux-glibc2.12-x86_64.tar.xz" =>
    "f3f1fd7d720883a8a16fe8ca3cb78150ad2f4008d251ce8ac0a2c676e2cf1e1f",

    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-linux-glibc2.12-i686.tar.xz" =>
    "b5a18de4e0b8c9209286d887bf187b8e7396e43d4b367870ca870ed95302fc7e",

    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-macos10.14-x86_64.tar.gz" =>
    "f6b1313e89b549947fa774e160a31cf051742110f7f27beadcdc0b4ebea7baa9",

    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-freebsd11-x86_64.tar.gz" =>
    "6099b7fc5444c183d0e1ca8973b32429c58060548c15a2056ed2d81269184a39",

]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
mkdir $prefix/lib

if [ $target = "x86_64-unknown-freebsd11.1" ]; then

  cp mysql-8.0.15-freebsd11-x86_64/lib/libmysqlclient.so.21 $prefix/lib/

elif [ $target = "x86_64-apple-darwin14" ]; then

  cp mysql-8.0.15-macos10.14-x86_64/lib/libmysqlclient.21.dylib $prefix/lib/

elif [ $target = "i686-linux-gnu" ]; then

  cp mysql-8.0.15-linux-glibc2.12-i686/lib/libmysqlclient.so.21.0.15 $prefix/lib/

else

  cp mysql-8.0.15-linux-glibc2.12-x86_64/lib/libmysqlclient.so.21.0.15 $prefix/lib/

fi

"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Linux(:x86_64, libc=:glibc),
    FreeBSD(:x86_64),
    Linux(:x86_64, libc=:musl),
    MacOS(:x86_64),
    Linux(:i686, libc=:glibc)
]

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "libmysqlclient", :libmysql)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)

