using BinaryBuilder

const prefix = Prefix("products")

const platform = ENV["BIT"] == "32" ? Windows(:i686) : Windows(:x86_64)

file, hash = package(prefix, "products\\MySQL"; platform=platform, verbose=true, force=true)

println("successfully packaged (\"$file\", \"$hash\")")
