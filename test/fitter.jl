
f(x, a, b) = a.*x .+ b
g(x) = x.^2

fitter = Fitter(f)

@test_throws ErrorException Fitter(g)
@test_throws ErrorException fit!(fitter)
@test_throws ErrorException set_data!(fitter, [1, 2, 3], [4, 5], [1, 2, 3])
@test_throws ErrorException results(fitter)

xdata = [1.0,2.0,3.0,4.0]
ydata = [0.0,1.0,3.0,5.5]

set_data!(fitter, xdata, ydata, 1.0)
@test fitter.eydata == [1.0, 1.0, 1.0, 1.0]

eydata = [0.5,0.4,0.8,0.5]

set_data!(fitter, xdata, ydata, eydata)
@test fitter.eydata == eydata

fit!(fitter)

# TODO: test fitting
