
@testset "fitter.jl" begin

f_test(x, a, b) = a.*x .+ b
g_test(x) = x.^2

println("  - Creating fitter_test...") # DELETE
fitter_test = Fitter(f_test)
println("  - Done creating fitter.") # DELETE

@test_throws EasyPhys.CannotFitException  Fitter(g_test)
# @test_throws EasyPhys.NoResultsException  results(fitter_test)
# @test_throws EasyPhys.BadDataException    fit!(fitter_test)
# @test_throws EasyPhys.BadDataException    set_data!(fitter_test, [1, 2, 3],
#                                                     [4, 5], [1, 2, 3])

xdata_test = [1.0, 2.0, 3.0, 4.0]
ydata_test = [0.0, 1.0, 3.0, 5.5]

println("  - Setting data...") # DELETE
set_data!(fitter_test, xdata_test, ydata_test, 1.0)
@test fitter_test.eydata == [1.0, 1.0, 1.0, 1.0]

eydata_test = [0.5, 0.4, 0.8, 0.5]

set_data!(fitter_test, xdata_test, ydata_test, eydata_test)
@test fitter_test.eydata == eydata_test
println("  - Done setting data.") # DELETE

println("  - Fitting...")
fit!(fitter_test)
println("  - Done fitting.")

# TODO: test fitting

end
