using BinaryBuilder

# Collection of sources required to build MySQL
sources = [
    "https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-6.1.11-linux-glibc2.12-i686.tar
.gz" => "32e463fda6613907b90d44228b3b81ad7508ce5e20a928b86ced47fbce1fe92a",
    "https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-6.1.11-linux-glibc2.12-x86_64
.tar.gz" => "149102915ea1f1144edb0de399c3392a55773448f96b150ec1568f700c00c929",
    "https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-6.1.11-win32.zip" => "a32487407bc0c4e21
7d8839892333fb0cb39153194d2788f226e9c5b9abdd928",
   "https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-6.1.11-winx64.zip" => "3555641cea2da6
0435ab7f1681a94d1aa97341f1a0f52193adc82a83734818ca",
    "https://dev.mysql.com/get/Downloads/Connector-C/mysql-connector-c-6.1.11-macos10.12-x86_64.tar.gz" => "c97d76936
c6caf063778395e7ca15862770a1ab77c1731269408a8d5c0eb4b93",
]

# Bash recipe for building across all platforms
script = raw"""
if [ $target == "i686-linux-gnu" ]; then
cd $WORKSPACE/srcdir
cp mysql-connector-c-6.1.11-linux-glibc2.12-i686/lib/libmysqlclient.so.18.4. $prefix/lib/libmysqlclient.so
elif [ $target == "x86_64-linux-gnu" ]; then
cd $WORKSPACE/srcdir
cp mysql-connector-c-6.1.11-linux-glibc2.12-x86_64/lib/libmysqlclient.so.18.4. $prefix/lib/libmysqlclient.so
elif [ $target == "i686-w64-mingw32" ]; then
cd $WORKSPACE/srcdir
cp mysql-connector-c-6.1.11-win32/lib/libmysql.dll $prefix/lib/libmysqlclient.dll
elif [ $target == "x86_64-w64-mingw32" ]; then
cd $WORKSPACE/srcdir
cp mysql-connector-c-6.1.11-winx64/lib/libmysql.dll $prefix/lib/libmysqlclient.dll
elif [ $target == "x86_64-apple-darwin14" ]; then
cd $WORKSPACE/srcdir
cp mysql-connector-c-6.1.11-macos10.12-x86_64/lib/libmysqlclient.18.dylib $prefix/lib/libmysqlclient.dylib
fi

"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Linux(:i686, :glibc),
    Linux(:x86_64, :glibc),
    Windows(:i686),
    Windows(:x86_64),
    MacOS()
]

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
