
using LsqFit
using DataArrays, DataFrames


import Base.getindex
import Base.setindex!
import Base.show


type CannotFitException <: Exception
    msg::AbstractString
end


type BadDataException <: Exception
    msg::AbstractString
end


type NoResultsException <: Exception
    msg::AbstractString
end


"""
Describes a set of data and a model to be fit to.
"""
type Fitter

    "Model function to fit to."
    f::Function

    "Parameters to be held constant when fitting."
    c::Dict{Symbol, Float64}

    "Data to be fitted to."
    data::DataFrame

    "Initial guesses for the best-fit parameters."
    guesses::Array{Float64, 1}

    "Whether the most recent fitting attempt has converged."
    _converged::Bool

    "Datapoints to be ignored when fitting."
    _outliers::BitArray{1}

    "Studentized residuals of the fit."
    _residuals::Nullable{Array{Float64, 1}}

    "Best-fit parameters and their uncertainties."
    _parameters::Dict{Symbol, Union{Tuple{Float64, Float64}, Void}}

    "Covariance matrix of the best-fit parameters."
    _covariance::Union{Array{Float64, 2}, Void}

    "Various settings for the fitter."
    _settings::Dict{Symbol, Any}

    "Function to use for fitting, taking only the required two parameters."
    _f_fitting::Function

    "Number of parameters to be fit to."
    _n_parameters::Int64

    "Figure number of the associated plot."
    _figure_number::Int64

end


# TODO: deal with constants
"""
    Fitter(f::Function; kwargs...)

    Fitter(f::Function, c::Dict{Symbol, Float64}; kwargs...)

Creates a new Fitter object with model function `f` and constants
described by `c` in the form `Dict(:constant_parameter_name => value)`.
"""
function Fitter(f::Function, c::Dict{Symbol, Float64}; kwargs...)

    residuals = Nullable{Array}()

    arg_names = argument_names(f)
    variable_name = arg_names[1]
    param_names = arg_names[2:end]

    parameters = Dict{Symbol, Any}([(p, nothing) for p in param_names])

    settings = Dict{Symbol, Any}(
            :error_range     => 0.68,
            :autoplot        => true,
            :xscale          => "linear",
            :yscale          => "linear",
            :plot_curve      => true,
            :plot_guess      => true,
            :fpoints         => 1000,
            :xmin            => nothing,
            :xmax            => nothing,
            :xlabel          => "$(variable_name)",
            :ylabel          => "f($(variable_name))",
            :xvar            => variable_name,
            :yvar            => :y,
            :eyvar           => :y_err,
            :style_data      => Dict(:marker => "+", :color => "b",   :ls => ""),
            :style_outliers  => Dict(:marker => "+", :color => "0.5", :ls => ""),
            :style_fit       => Dict(:marker => "",  :color => "r",   :ls => "-"),
            :style_guess     => Dict(:marker => "",  :color => "k",   :ls => "--")
        )

    merge!(settings, Dict(kwargs))

    n_parameters = number_of_arguments(f) - 1 # remove one for the x

    if n_parameters == 0
        throw(CannotFitException("Cannot fit to a function with " *
                                 "only one free parameter."))
    end

    f_fitting(x, p) = f(x, p...)

    data          = DataFrame()
    converged     = false
    covariance    = nothing
    figure_number = -1
    outliers      = BitArray{1}()
    guesses       = ones(n_parameters)

    Fitter(f, c, data, guesses, converged, outliers, residuals, parameters,
           covariance, settings, f_fitting, n_parameters, figure_number)
end


Fitter(f::Function; kwargs...) = Fitter(f, Dict{Symbol, Float64}(); kwargs...)


setindex!(fitter::Fitter, val, key) = fitter._settings[key] = val


function getindex(fitter::Fitter, key)
    val = nothing
    if key ∈ keys(fitter._settings)
        val = fitter._settings[key]
    elseif key ∈ keys(fitter._parameters)
        if fitter._converged
            val = fitter._parameters[key]
        else
            throw(NoResultsException("Fit results cannot be accessed until " *
                                     "`fit!` has been called successfully."))
        end
    else
        throw(KeyError(key))
    end
    val
end


function show(stream::IO, fitter::Fitter)
    description = "EasyPhys.Fitter with the following settings:\n\n"
    for (k, v) in fitter._settings
        description *= "\t$(rpad(k, 15)) => $(repr(v))\n"
    end
    description *= "\n"

    try
        χ²_guess = reduced_χ²(fitter, fitter.guesses)
        description *= "Guesses (χ² = $(χ²_guess)):\n\n"
    catch e
        if isa(e, BadDataException)
            description *= "Guesses:\n\n"
        else
            rethrow(e)
        end
    end

    for (i, key) in enumerate(keys(fitter._parameters))
        description *= "\t$(rpad(key, 15)) = "
        description *= "$(fitter.guesses[i])\n"
    end
    description *= "\n"

    if fitter._converged
        χ²_fit = reduced_χ²(fitter)
        description *= "Best-fit parameters (χ² = $(χ²_fit)):\n\n"
        for (key, (val, err)) in fitter._parameters
            description *= "\t$(rpad(key, 15)) = "
            description *= "$(val) ± $(err)\n"
        end
    else
        description *= "Fit results not yet present."
    end

    write(stream, description)
end


"""
    xdata(fitter::Fitter)

Gets the dependent data associated with `fitter`.
"""
xdata(fitter::Fitter) = fitter.data[fitter[:xvar]]


"""
    ydata(fitter::Fitter)

Gets the independent data associated with `fitter`.
"""
ydata(fitter::Fitter) = fitter.data[fitter[:yvar]]


"""
    eydata(fitter::Fitter)

Gets the errors in the independent data associated with `fitter`.
"""
eydata(fitter::Fitter) = fitter.data[fitter[:eyvar]]


"""
    set!(fitter::Fitter; kwargs...)

    (fitter::Fitter) |> set!(; kwargs...)

Updates the settings of `fitter` from the values given in `kwargs`.
Returns `fitter` so that similar calls can be chained together.
"""
@partially_applicable function set!(fitter::Fitter; kwargs...)
    for (k, v) in kwargs
        fitter[k] = v
    end

    fitter
end


"""
    set_data!(fitter::Fitter, xdata, ydata, eydata)

    set_data!(fitter::Fitter, dataframe)

    (fitter::Fitter) |> set_data!(xdata, ydata, eydata)

    (fitter::Fitter) |> set_data!(dataframe)

Updates the data associated with `fitter`. If a DataFrame is supplied, three
columns must be present in the order [xdata, ydata, eydata]. Returns `fitter`
so that similar calls can be chained together.
"""
@partially_applicable function set_data!(fitter::Fitter, xdata, ydata, eydata)
    n_data = length(xdata)
    if length(ydata) ≠ n_data
        throw(BadDataException("xdata and ydata must have the " *
                               "same number of data"))
    end

    if typeof(eydata) <: Number
        eydata = eydata * ones(xdata)
    elseif length(eydata) ≠ n_data
        throw(BadDataException("eydata must be broadcastable to " *
                               "the size of xdata and ydata"))
    end

    dataframe = DataFrame(Any[xdata, ydata, eydata], [:x, :y, :y_err])

    set_data!(fitter, dataframe)
end


@partially_applicable function set_data!(fitter::Fitter, dataframe::DataFrame,
        xvar=nothing, yvar=nothing, eyvar=nothing)
    if (size(dataframe, 2) ≠ 3)
        throw(BadDataException("Exactly 3 columns of data must be supplied."))
    end

    if is( xvar, nothing)  xvar = names(dataframe)[1] end
    if is( yvar, nothing)  yvar = names(dataframe)[2] end
    if is(eyvar, nothing) eyvar = names(dataframe)[3] end

    fitter[:xvar] = xvar
    fitter[:yvar] = yvar
    fitter[:eyvar] = eyvar

    n_data = size(dataframe, 1)
    fitter._outliers = BitArray{1}(repeat([false], outer=n_data))

    fitter.data = dataframe

    if fitter[:autoplot]
        plot!(fitter)
    end

    fitter
end


"""
    apply_mask!(fitter::Fitter, mask::BitArray{1})

    (fitter::Fitter) |> apply_mask!(mask::BitArray{1})

Applies `mask` to the data associated with `fitter`. Returns `fitter`
so that similar calls can be chained together.
"""
@partially_applicable function apply_mask!(fitter::Fitter, mask::BitArray{1})
    fitter._outliers = ~mask

    if fitter[:autoplot]
        plot!(fitter)
    end

    fitter
end


"""
    ignore_outliers!(fitter::Fitter, max_residual=10, params=[])

    (fitter::Fitter) |> ignore_outliers!(max_residual=10, params=[])

Ignores outlying datapoints associated with `fitter`, defined as those points
the studentized residuals of which are larger than `max_residual` when the
model function is evaluated with `params`. If no `params` are provided, uses
fit results.
"""
@partially_applicable function ignore_outliers!(
        fitter::Fitter, max_residual=10, params=[])
    outliers = abs(studentized_residuals(fitter, params)) .> max_residual
    fitter |> apply_mask!(~outliers)
end


"""
    xlims(fitter::Fitter)

Gets the active x-limits `xmin` and `xmax` of `fitter`.
"""
function xlims(fitter::Fitter)
    xmin = is(fitter[:xmin], nothing) ? minimum(xdata(fitter)) : fitter[:xmin]
    xmax = is(fitter[:xmax], nothing) ? maximum(xdata(fitter)) : fitter[:xmax]

    (xmin, xmax)
end


"""
    data_mask(fitter::Fitter)

Returns a mask indexing data which are within the fitting limits of `fitter`,
as determined by `fitter[:xmin]` and `fitter[:xmax]` as well as any outliers.
"""
function data_mask(fitter::Fitter)
    xmin, xmax = xlims(fitter)

    (xmin .<= xdata(fitter) .<= xmax) & ~fitter._outliers
end


"""
    fit!(fitter::Fitter, guesses; kwargs...)

    fit!(fitter::Fitter; kwargs...)

    (fitter::Fitter) |> fit!(guesses; kwargs...)

    (fitter::Fitter) |> fit!(; kwargs...)

Fits the model function of `fitter` to the associated data. Updates the
settings of `fitter` from the values given in `kwargs` before fitting.
If provided, `guesses` are used as the initial guesses for the parameters
being fit to. Returns `fitter` so that similar calls can be chained together.
"""
@partially_applicable function fit!(fitter::Fitter, guesses=nothing; kwargs...)
    if size(fitter.data, 1) == 0
        throw(BadDataException("All xdata, ydata, and eydata must be set " *
                               "before calling `fit!`."))
    end

    set!(fitter; kwargs...)

    if guesses ≠ nothing
        if length(guesses) == (len = length(fitter.guesses))
            fitter.guesses = guesses
        else
            warn("If supplied, `guesses` must be of length $(len). " *
                 "Using old guesses.")
        end
    end

    fit_mask = data_mask(fitter)
    xdata_fit = xdata(fitter)[fit_mask]
    ydata_fit = ydata(fitter)[fit_mask]
    eydata_fit = eydata(fitter)[fit_mask]

    weights = 1 ./ abs(eydata_fit)
    fit_results = curve_fit(fitter._f_fitting, xdata_fit, ydata_fit,
                            weights, fitter.guesses)

    if fit_results.converged
        fitter._converged = true

        params = fit_results.param
        param_errors = estimate_errors(fit_results, fitter[:error_range])

        for (i, k) in enumerate(keys(fitter._parameters))
            fitter._parameters[k] = (params[i], param_errors[i])
        end

        fitter._covariance = estimate_covar(fit_results)
        fitter._residuals = Nullable{Array}(-fit_results.resid)

        if fitter[:autoplot]
            plot!(fitter)
        end
    else
        fitter._converged = false

        warn("Fit did not converge.")
    end

    fitter
end


"""
    parameter_covariance(fitter::Fitter)

Computes the covariance matrix of the best-fit parameters associated with `fitter`.
"""
parameter_covariance(fitter::Fitter) = fitter._covariance


"""
    studentized_residuals(fitter::Fitter)

Computes the studentized residuals of the fit described by `fitter`.
"""
function studentized_residuals(fitter::Fitter, params=[])
    if size(fitter.data, 1) == 0
        throw(BadDataException("All xdata, ydata, and eydata must be set " *
                               "in order to calculate residuals."))
    end

    resids = []
    if isempty(params)
        if fitter._converged
            resids = get(fitter._residuals)
        else
            throw(NoResultsException("Fit must converge before residuals can " *
                                     "be accessed."))
        end
    else
        fit_mask = data_mask(fitter)
        weights = 1 ./ abs(eydata(fitter)[fit_mask])
        resids = ydata(fitter)[fit_mask]
               - apply_f(fitter, xdata(fitter)[fit_mask], params)
        resids .*= weights
    end

    resids
end


"""
    reduced_χ²(fitter::Fitter)

Computes the reduced χ² of the fit described by `fitter`.
"""
function reduced_χ²(fitter::Fitter, params=[])
    squared_residuals = studentized_residuals(fitter, params).^2

    n_params = isempty(params) ? length(fitter._parameters) : length(params)
    ndof = countnz(data_mask(fitter)) - n_params

    sum(squared_residuals) / ndof
end


"""
    apply_f(fitter::Fitter, x)

    apply_f(fitter::Fitter, x, params)

    (fitter::Fitter) |> apply_f(x)

Applies the model function of `fitter` at points `x` using parameters `params`.
If no `params` is supplied and fit! has been called, defaults to using the
best-fit parameters.
"""
@partially_applicable function apply_f(fitter::Fitter, x, params=[])
    if isempty(params)
        params = [v for (v, _) in values(fitter._parameters)]
    end
    fitter._f_fitting(x, params)
end
