using BinaryBuilder, BinaryProvider

# Collection of sources required to build MySQL
sources = Dict(
    Linux(:i686, :glibc) => "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-linux-glibc2.12-i686.tar.xz"=>"b5a18de4e0b8c9209286d887bf187b8e7396e43d4b367870ca870ed95302fc7e",
    Linux(:x86_64, :glibc) => "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-linux-glibc2.12-x86_64.tar.xz"=>"f3f1fd7d720883a8a16fe8ca3cb78150ad2f4008d251ce8ac0a2c676e2cf1e1f",
    MacOS() => "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-macos10.14-x86_64.tar.gz"=>"f6b1313e89b549947fa774e160a31cf051742110f7f27beadcdc0b4ebea7baa9",
    FreeBSD(:x86_64) => "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-freebsd11-x86_64.tar.gz"=>"6099b7fc5444c183d0e1ca8973b32429c58060548c15a2056ed2d81269184a39",
    Windows(:x86_64) => "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.15-winx64.zip"=>"16bf0ad985dd862c81f030438e7907872c2989fbb67548177f5853803d3fb803",
)

product_hashes = Dict()

mkpath(joinpath(pwd(), "products"))

for (platform, (url, hash)) in sources
    println("downloading $url")
    if platform == Windows(:x86_64)
        @assert BinaryProvider.download_verify(url, hash, joinpath(pwd(), "out", "mysql.zip"); force=true)
        println("unzipping $(joinpath(pwd(), "out", "mysql.zip"))")
        success(`unzip $(joinpath(pwd(), "out", "mysql.zip")) -d $(joinpath(pwd(), "out")) -v`)
        spl(x) = splitext(basename(x))[1]
    else
        @assert BinaryProvider.download_verify_unpack(url, hash, joinpath(pwd(), "out"); force=true)
        spl(x) = splitext(splitext(basename(x))[1])[1]
    end
    println("removing uneeded files...")
    rm(joinpath(pwd(), "out", spl(url), "bin"); force=true, recursive=true)
    rm(joinpath(pwd(), "out", spl(url), "docs"); force=true, recursive=true)
    rm(joinpath(pwd(), "out", spl(url), "share"); force=true, recursive=true)
    filepath = joinpath(pwd(), "products", string("MySQL.$(triplet(platform)).tar.gz"))
    println("packaging $(joinpath(pwd(), "out", spl(url))) into $filepath...")
    BinaryProvider.package(joinpath(pwd(), "out", spl(url)), filepath)
    product_hashes[triplet(platform)] = open(filepath) do file
        BinaryBuilder.bytes2hex(BinaryBuilder.sha256(file))
    end
    rm(joinpath(pwd(), "out"); force=true, recursive=true)
end

# The products that we will ensure are always built
products(prefix) = Product[
    LibraryProduct(prefix, "libmysqlclient", :libmysql)
]

# If we're only reconstructing a build.jl file on Travis, grab the information and do it
if !haskey(ENV, "TRAVIS_REPO_SLUG") || !haskey(ENV, "TRAVIS_TAG")
    error("Must provide repository name and tag through Travis-style environment variables!")
end
repo_name = ENV["TRAVIS_REPO_SLUG"]
tag_name = ENV["TRAVIS_TAG"]
bin_path = "https://github.com/$(repo_name)/releases/download/$(tag_name)"
dummy_prefix = Prefix(pwd())
print_buildjl(pwd(), "MySQL", v"8.0.15", products(dummy_prefix), product_hashes, bin_path)

println("Writing out the following reconstructed build.jl:")
print_buildjl(stdout, products(dummy_prefix), product_hashes, bin_path)
