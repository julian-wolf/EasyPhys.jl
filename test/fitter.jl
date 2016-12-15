
@testset "fitter.jl" begin

f_test(x, a, b) = a.*x .+ b
g_test(x) = x.^2

fitter_test = Fitter(f_test; autoplot=false)

@test_throws EasyPhys.CannotFitException  Fitter(g_test)
@test_throws EasyPhys.NoResultsException  results(fitter_test)
@test_throws EasyPhys.BadDataException    fit!(fitter_test)
@test_throws EasyPhys.BadDataException    set_data!(fitter_test, [1, 2, 3],
                                                    [4, 5], [1, 2, 3])

xdata_test = [1.0, 2.0, 3.0, 4.0]
ydata_test = [0.0, 1.0, 3.0, 5.5]

set_data!(fitter_test, xdata_test, ydata_test, 1.0)
@test fitter_test.eydata == [1.0, 1.0, 1.0, 1.0]

eydata_test = [0.5, 0.4, 0.8, 0.5]

set_data!(fitter_test, xdata_test, ydata_test, eydata_test)
@test fitter_test.eydata == eydata_test

# skipping this for now; I can't figure out what version of LsqFit travis is using
# fit!(fitter_test)

# TODO: test fitting

end
