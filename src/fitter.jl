
# TODO: clean up Exceptions

"""
Describes a set of data and a model to be fit to.
"""
type Fitter

    "Model function to fit to."
    f::Function

    "Datapoints for the independent variable x."
    xdata::Array{Float64, 1}

    "Datapoints for the dependent variable y."
    ydata::Array{Float64, 1}

    "Errors (standard deviations) in the y datapoints."
    eydata::Array{Float64, 1}

    "Initial guesses for the best-fit parameters."
    guesses::Array{Float64, 1}

    "Results of the least-squares optimization."
    _results::Nullable{LsqFit.LsqFitResult{Float64}}

    "Various settings for the fitter."
    _settings::Dict{Symbol, Any}

    "Function to use for fitting, taking only the required two parameters."
    _f_fitting::Function

    "Number of parameters to be fit to."
    _n_parameters::Int64

end


"""
    Fitter(f::Function; kwargs...)

Creates a new Fitter object with model function `f`.
"""
function Fitter(f::Function; kwargs...)
    results = Nullable{LsqFit.LsqFitResult}()

    settings = Dict(
            :autoplot    => true,
            :xscale      => "linear",
            :yscale      => "linear",
            :plot_curve  => true,
            :plot_guess  => true,
            :fpoints     => 1000,
            :xmin        => nothing,
            :xmax        => nothing,
            :xlabel      => "x",
            :ylabel      => "f(x)",
            :style_data  => Dict(:marker => "+", :color => "b", :ls => ""),
            :style_fit   => Dict(:marker => "",  :color => "r", :ls => "-"),
            :style_guess => Dict(:marker => "",  :color => "k", :ls => "--")
        )

    for (k, v) in kwargs
        settings[k] = v
    end

    n_parameters = number_of_arguments(f) - 1 # remove one for the x

    if n_parameters == 0
        error("Cannot fit to a function with only one free parameter.")
    elseif n_parameters == 1
        f_fitting = f
    else
        f_fitting(x, p) = f(x, p...)
    end

    Fitter(f, [], [], [], [], results, settings, f_fitting, n_parameters)
end


"""
    set!(fitter::Fitter; kwargs...)

Updates the settings of `fitter` from the values given in `kwargs`.
Returns `fitter` so that similar calls can be chained together.
"""
function set!(fitter::Fitter; kwargs...)
    for (k, v) in kwargs
        fitter._settings[k] = v
    end

    fitter
end


"""
    set_data!(fitter::Fitter, xdata, ydata, eydata)

Updates the data associated with `fitter`. Returns `fitter` so that
similar calls can be chained together.
"""
function set_data!(fitter::Fitter, xdata, ydata, eydata)
    n_data = length(xdata)
    if length(ydata) ≠ n_data
        error("xdata and ydata must have the same number of data")
    end

    if length(eydata) == 1
        if typeof(eydata) <: AbstractVector
            eydata = eydata[1]
        end
        eydata = eydata * ones(xdata)
    elseif length(eydata) ≠ n_data
        error("eydata must be broadcastable to the size of xdata and ydata")
    end

    fitter.xdata = xdata
    fitter.ydata = ydata
    fitter.eydata = eydata

    fitter
end


setindex!(fitter::Fitter, val, key) = fitter._settings[key] = val


getindex(fitter::Fitter, key) = fitter._settings[key]


function Base.show(stream::IO, fitter::Fitter)
    description = "EasyPhys.Fitter with the following settings:\n\n"
    for (k, v) in fitter._settings
        description *= "\t$(rpad(k, 15)) => $(repr(v))\n"
    end
    description *= "\n"

    try
        χ² = reduced_χ²(fitter)
        description *= "Fit succeeded with reduced χ² = $χ². "

        fit_params = results(fitter).param
        fit_errors = parameter_errors(fitter)
        description *= "Best-fit parameters:\n\n"
        param_names = argument_names(fitter.f)[2:end] # skip the x
        for i = 1:fitter._n_parameters
            description *= "\t$(rpad(param_names[i], 15)) = "
            description *= "$(fit_params[i]) ± $(fit_errors[i])\n"
        end
    catch e
        if isa(e, ErrorException)
            description *= "Fit results not yet present."
        else
            rethrow(e)
        end
    end

    write(stream, description)
end


"""
    xlims(fitter::Fitter)

Gets the active x-limits `xmin` and `xmax` of `fitter`.
"""
function xlims(fitter::Fitter)
    xmin = is(fitter[:xmin], nothing) ? minimum(fitter.xdata) : fitter[:xmin]
    xmax = is(fitter[:xmax], nothing) ? maximum(fitter.xdata) : fitter[:xmax]

    (xmin, xmax)
end

"""
    data_mask(fitter::Fitter)

Returns a mask indexing data which are within the fitting limits of `fitter`,
as determined by `fitter[:xmin]` and `fitter[:xmax]`.
"""
function data_mask(fitter::Fitter)
    xmin, xmax = xlims(fitter)

    xmin .<= fitter.xdata .<= xmax
end


"""
    fit!(fitter::Fitter; kwargs...)

Fits the model function of `fitter` to the associated data. Updates the
settings of `fitter` from the values given in `kwargs` before fitting.
Returns `fitter` so that similar calls can be chained together.
"""
function fit!(fitter::Fitter; kwargs...)
    if [] ∈ (fitter.xdata, fitter.ydata, fitter.eydata)
        error("All xdata, ydata, and eydata must be set before calling fit!.")
    end

    if isempty(fitter.guesses)
        fitter.guesses = ones(fitter._n_parameters)
    end

    set!(fitter, kwargs...)

    fit_mask = data_mask(fitter)
    xdata_fit = fitter.xdata[fit_mask]
    ydata_fit = fitter.ydata[fit_mask]
    eydata_fit = fitter.eydata[fit_mask]

    weights = 1 ./ abs(eydata_fit)
    fitter._results = Nullable(curve_fit(fitter._f_fitting, xdata_fit, ydata_fit,
                                         weights, fitter.guesses))

    if fitter[:autoplot]
        plot(fitter)
    end

    fitter
end


"""
    fit!(fitter::Fitter, p0; kwargs...)

Fits the model function of `fitter` to the associated data using initial
parameter guesses `p0`. Updates the settings of `fitter` from the values
given in `kwargs` before fitting. Returns `fitter` so that similar calls
can be chained together.
"""
function fit!(fitter::Fitter, p0; kwargs...)
    fitter.guesses = p0
    fit!(fitter, kwargs)
end


"""
    results(fitter::Fitter)

Returns the results of fitting `fitter`, of type `LsqFitResult`. This has
fields `dof`, `param`, `resid`, and `jacobian`.
"""
function results(fitter::Fitter)
    if isnull(fitter._results)
        error("fit! must be called on fitter before results can be accessed.")
    end

    get(fitter._results)
end


"""
    parameter_errors(fitter::Fitter, alpha)

Computes the errors in the best-fit parameters associated with `fitter` to
the confidence interval described by `alpha`.
"""
function parameter_errors(fitter::Fitter, alpha=0.68)
    fit_results = results(fitter)
    estimate_errors(fit_results, alpha)
end


"""
    parameter_covariance(fitter::Fitter)

Computes the covariance matrix of the best-fit parameters associated with `fitter`.
"""
function parameter_covariance(fitter::Fitter)
    fit_results = results(fitter)
    estimate_covar(fit_results)
end


"""
    studentized_residuals(fitter::Fitter)

Computes the studentized residuals of the fit described by `fitter`.
"""
function studentized_residuals(fitter::Fitter)
    fit_results = results(fitter)
    fit_mask = data_mask(fitter)
    weights = 1 ./ abs(fitter.eydata[fit_mask])
    -fit_results.resid .* weights
end


"""
    reduced_χ²(fitter::Fitter)

Computes the reduced χ² of the fit described by `fitter`.
"""
function reduced_χ²(fitter::Fitter)
    squared_residuals = studentized_residuals(fitter).^2
    # ndof = countnz(data_mask(fitter)) - fitter._n_parameters
    ndof = results(fitter).dof
    sum(squared_residuals) / ndof
end


"""
    apply_f(fitter::Fitter, x)
    apply_f(fitter::Fitter, x, params)

Applies the model function of `fitter` at points `x` using parameters `params`.
If no `params` is supplied and fit! has been called, defaults to using the
best-fit parameters.
"""
function apply_f(fitter::Fitter, x, params=[])
    if isempty(params)
        fit_results = results(fitter)
        params = fit_results.param
    end
    fitter._f_fitting(x, params)
end
