
@testset "plot.jl" begin

model_test(x, a, b) = a .* exp.(-x .* b)

xdata_test = linspace(0, 10, 100)
ydata_test = model_test(xdata_test, 1, 2) + 0.01*randn(length(xdata_test))
eydata_test = 0.01;

fitter_a_test = Fitter(model_test; autoplot=false)
fitter_b_test = Fitter(model_test; autoplot=false)

fig_a_test = set_data!(fitter_a_test, xdata_test, ydata_test, eydata_test) |> plot!
fig_b_test = set_data!(fitter_b_test, xdata_test, ydata_test, eydata_test) |> plot!

@test fig_a_test ≠ fig_b_test

fit!(fitter_a_test)

@test fig_a_test == ignore_outliers!(fitter_a_test, 1) |> fit! |> plot!

@test fig_a_test ≠ plot(fitter_a_test)

end
