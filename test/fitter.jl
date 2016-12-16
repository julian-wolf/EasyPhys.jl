
@testset "fitter.jl" begin

f_test(x, a, b) = a.*x .+ b
g_test(x) = x.^2

fitter_test = Fitter(f_test; autoplot=false)

@testset "fitter.jl exceptions" begin
    @test_throws EasyPhys.CannotFitException  Fitter(g_test)
    @test_throws EasyPhys.NoResultsException  results(fitter_test)
    @test_throws EasyPhys.BadDataException    fit!(fitter_test)
    @test_throws EasyPhys.BadDataException    set_data!(fitter_test, [1, 2, 3],
                                                        [4, 5], [1, 2, 3])
    @test_throws EasyPhys.BadDataException    set_data!(fitter_test, [1, 2, 3],
                                                        [4, 5, 6], [1, 2])
end

@testset "fitter.jl `fit!` and friends" begin
    tolerance_test = 0.08
    outlier_threshold_test = 2

    model_test(x, a, b) = a*exp(-x*b)

    xdata_test = linspace(0, 10, 100)
    eydata_test = 0.01;

    fitter_test = Fitter(model_test) |> set!(autoplot=false)

    for a in 1:10:91, b in 1:10
        ydata_test = model_test(xdata_test, a, b) + 0.01*randn(length(xdata_test))

        set_data!(fitter_test, xdata_test, ydata_test, eydata_test) |> fit!
        χ²_init_test = reduced_χ²(fitter_test, [a, b])
        χ²_worse_test = reduced_χ²(fitter_test)

        @test all(abs(results(fitter_test).param .- [a, b]) ./ [a, b]
                  .<= tolerance_test)

        ignore_outliers!(fitter_test, outlier_threshold_test) |> fit!
        χ²_better_test = reduced_χ²(fitter_test)

        @test χ²_init_test >= χ²_worse_test >= χ²_worse_test

        y_true_test = model_test(xdata_test, a, b)
        @test all(apply_f(fitter_test, xdata_test, [a, b]) == y_true_test)
    end

    fitter_test[:xmax] = 90
    fit!(fitter_test, [11, 6])
    fit!(fitter_test, [5])
end

end
