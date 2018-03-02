using BinaryBuilder

# Collection of sources required to build MySQL
sources = [
    "https://downloads.mariadb.com/Connectors/c/connector-c-3.0.3/mariadb-connector-c-3.0.3-src.tar.gz" =>
    "210f0ee3414b235d3db8e98e9e5a0a98381ecf771e67ca4a688036368984eeea",
     "https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-6.1.11-macos10.12-x86_64.tar.gz" =>
    "c97d76936c6caf063778395e7ca15862770a1ab77c1731269408a8d5c0eb4b93",
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
fi
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Linux(:i686, :glibc),
    Linux(:x86_64, :glibc),
    Linux(:aarch64, :glibc),
    Linux(:armv7l, :glibc),
    Linux(:powerpc64le, :glibc),
    MacOS()
]

# The products that we will ensure are always built
products(prefix) = Product[
    LibraryProduct(prefix, "libmariadb", :libmariadb)
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
