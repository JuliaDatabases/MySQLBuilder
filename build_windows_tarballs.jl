using BinaryBuilder

const prefix = Prefix("products")

file, hash = package(prefix, "MySQL"; platform=Windows(:i686), verbose=true, force=true)
file2, hash2 = package(prefix, "MySQL"; platform=Windows(:x86_64), verbose=true, force=true)

@show readdir()
@show readdir("products")

println("""
Windows(:i686) => (\"\$bin_prefix/$file\", \"$hash\"),
Windows(:x86_64) => (\"\$bin_prefix/$file2\", \"$hash2\")
""")