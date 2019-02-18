using BinaryBuilder

# Collection of sources required to build MySQL
sources = [
    # linux 64-bit
    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-linux-glibc2.12-x86_64.tar.xz" => "f3f1fd7d720883a8a16fe8ca3cb78150ad2f4008d251ce8ac0a2c676e2cf1e1f",
    # linux 32-bit
    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-linux-glibc2.12-i686.tar.xz" => "b5a18de4e0b8c9209286d887bf187b8e7396e43d4b367870ca870ed95302fc7e",
    # macOS
    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-macos10.14-x86_64.tar.gz" => "f6b1313e89b549947fa774e160a31cf051742110f7f27beadcdc0b4ebea7baa9",
    # freeBSD
    "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-freebsd11-x86_64.tar.gz" => "6099b7fc5444c183d0e1ca8973b32429c58060548c15a2056ed2d81269184a39",
]

# Bash recipe for building across all platforms
script = raw"""
if [ $target == "x86_64-apple-darwin14" ]; then
    cd $WORKSPACE/srcdir
    mkdir $prefix/lib
    cp mysql-connector-c-6.1.11-macos10.12-x86_64/lib/libmysqlclient.18.dylib $prefix/lib/libmariadb.dylib
else
    cd $WORKSPACE/srcdir
    cd mariadb-connector-c-3.0.3-src/
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$prefix -DCMAKE_TOOLCHAIN_FILE=/opt/$target/$target.toolchain
    make && make install
    mv $prefix/lib/mariadb/* $prefix/lib/.
fi
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = filter(x->BinaryProvider.platform_name(x)!="Windows", supported_platforms())

# The products that we will ensure are always built
products(prefix) = Product[
    LibraryProduct(prefix, "libmysqlclient", :libmysql)
]

# Dependencies that must be installed before this package can be built
dependencies = [
]

# Parse out some command-line arguments
BUILD_ARGS = ARGS

# This sets whether we should build verbosely or not
verbose = "--verbose" in BUILD_ARGS
BUILD_ARGS = filter!(x -> x != "--verbose", BUILD_ARGS)

# This flag skips actually building and instead attempts to reconstruct a
# build.jl from a GitHub release page.  Use this to automatically deploy a
# build.jl file even when sharding targets across multiple CI builds.
only_buildjl = "--only-buildjl" in BUILD_ARGS
BUILD_ARGS = filter!(x -> x != "--only-buildjl", BUILD_ARGS)

if !only_buildjl
    # If the user passed in a platform (or a few, comma-separated) on the
    # command-line, use that instead of our default platforms
    if length(BUILD_ARGS) > 0
        platforms = platform_key.(split(BUILD_ARGS[1], ","))
    end
    info("Building for $(join(triplet.(platforms), ", "))")

    # Build the given platforms using the given sources
    autobuild(pwd(), "MySQL", platforms, sources, script, products;
                                      dependencies=dependencies, verbose=verbose)
    @show readdir("products")
else
    # If we're only reconstructing a build.jl file on Travis, grab the information and do it
    if !haskey(ENV, "TRAVIS_REPO_SLUG") || !haskey(ENV, "TRAVIS_TAG")
        error("Must provide repository name and tag through Travis-style environment variables!")
    end
    repo_name = ENV["TRAVIS_REPO_SLUG"]
    tag_name = ENV["TRAVIS_TAG"]
    product_hashes = product_hashes_from_github_release(repo_name, tag_name; verbose=verbose)
    bin_path = "https://github.com/$(repo_name)/releases/download/$(tag_name)"
    dummy_prefix = Prefix(pwd())
    print_buildjl(pwd(), products(dummy_prefix), product_hashes, bin_path)

    if verbose
        info("Writing out the following reconstructed build.jl:")
        print_buildjl(STDOUT, product_hashes; products=products(dummy_prefix), bin_path=bin_path)
    end
end
