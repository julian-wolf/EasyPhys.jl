using EasyPhys
using Base.Test

test_files = ["utilities.jl", "fitter.jl"]

println("Running tests:")

for test in test_files
    println(" * Running tests on $(test)...")
    include(test)
end
