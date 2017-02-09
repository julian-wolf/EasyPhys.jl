
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

    "Data to be fitted to."
    data::DataFrame

    "Fit parameters with initial guesses, best-fit values, and their uncertainties."
    _parameters::ModelParameters

    "Whether the most recent fitting attempt has converged."
    _converged::Bool

    "Datapoints to be ignored when fitting."
    _outliers::BitArray{1}

    "Studentized residuals of the fit."
    _residuals::Nullable{Array{AbstractFloat, 1}}

    "Covariance matrix of the best-fit parameters."
    _covariance::Union{Array{Float64, 2}, Void}

    "Various settings for the fitter."
    _settings::Dict{Symbol, Any}

    "Function to use for fitting, taking only the required two parameters."
    _f_fitting::Function

    "Figure number of the associated plot."
    _figure_number::Integer

end


"""
    Fitter(f::Function; kwargs...)

Creates a new Fitter object with model function `f`.
"""
function Fitter(f::Function; kwargs...)

    residuals = Nullable{Array}()

    arg_names = argument_names(f)
    variable_name = arg_names[1]
    param_names = arg_names[2:end]

    parameters = ModelParameters(
        [(p, FreeParameter(i, 1.0)) for (i, p) in enumerate(param_names)])

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
            :style_guess     => Dict(:marker => "",  :color => "k",   :ls => "--"))

    merge!(settings, Dict(kwargs))

    n_parameters = number_of_arguments(f) - 1 # remove one for the x

    if n_parameters == 0
        msg = "Cannot fit to a function with only one free parameter."
        throw(CannotFitException(msg))
    end

    f_fitting(x, p) = f(x, p...)

    data          = DataFrame()
    converged     = false
    covariance    = nothing
    figure_number = -1
    outliers      = BitArray{1}()

    Fitter(
        f, data, parameters, converged, outliers, residuals, covariance,
        settings, f_fitting, figure_number)
end


function setindex!(fitter::Fitter, val, key)
    if key ∈ keys(fitter._settings)
        fitter._settings[key] = val
    elseif key ∈ keys(fitter._parameters)
        fitter._parameters[key].value = val
    else
        throw(KeyError(key))
    end
end


function getindex(fitter::Fitter, key)
    val = nothing
    if key ∈ keys(fitter._settings)
        val = fitter._settings[key]
    elseif key ∈ keys(fitter._parameters)
        if isa(fitter._parameters[key], FixedParameter)
            val = fitter._parameters[key].value
        else
            if fitter._converged
                val = get(fitter._parameters[key].fit_value)
            else
                msg = "Fit results cannot be accessed until " *
                      "`fit!` has been called successfully."
                throw(NoResultsException(msg))
            end
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

    if n_free_parameters(fitter) < length(fitter._parameters)
        description *= "Constants:\n\n"
        for (key, val) in fitter._parameters
            if isa(val, FixedParameter)
                description *= "\t$(rpad(key, 15)) = $(val.value)\n"
            end
        end
        description *= "\n"
    end

    try
        χ²_guess = reduced_χ²(fitter, guesses(fitter))
        description *= "Guesses (χ² = $(χ²_guess)):\n\n"
    catch e
        if isa(e, BadDataException)
            description *= "Guesses:\n\n"
        else
            rethrow(e)
        end
    end

    for (key, val) in sort(
            [(k, v) for (k, v) in fitter._parameters if isa(v, FreeParameter)],
            by=(kv -> kv[2].position))
        description *= "\t$(rpad(key, 15)) = $(fitter._parameters[key].value)\n"
    end
    description *= "\n"

    if fitter._converged
        χ²_fit = reduced_χ²(fitter)
        description *= "Best-fit parameters (χ² = $(χ²_fit)):\n\n"
        for (key, val) in sort(
                [(k, v) for (k, v) in fitter._parameters if isa(v, FreeParameter)],
                by=(kv -> kv[2].position))
            description *= "\t$(rpad(key, 15)) = "
            description *= "$(get(val.fit_value)) ± "
            description *= "$(get(val.fit_uncertainty))\n"
        end
    else
        description *= "Fit results not yet present."
    end
    description *= "\n"

    write(stream, description)
end


"""
    null_results!(fitter::Fitter)

    null_results!(model_parameters::ModelParameters)

Sets all the `best_fit_value` and `fit_uncertainty` fields of `fitter`
or `model_parameters` to null.
"""
function null_results!(model_parameters::ModelParameters)
    for val in values(model_parameters)
        if isa(val, FreeParameter)
            val.fit_value       = Nullable{AbstractFloat}()
            val.fit_uncertainty = Nullable{AbstractFloat}()
        end
    end
end


null_results!(fitter::Fitter) = null_results!(fitter._parameters)


"""
    free!(fitter::Fitter, parameters...)

    (fitter::Fitter) |> free!(parameters...)

Frees `parameters` from any constraints when fitting. Returns `fitter`
so that similar calls can be chained together.
"""
@partially_applicable function free!(fitter::Fitter, parameters...)
    for parameter in parameters
        free!(fitter._parameters[parameter])
    end

    null_results!(fitter)

    fitter
end


function free!(parameter::ModelParameter)
    parameter = FreeParameter(parameter.position, parameter.value)
end



"""
    fix!(fitter::Fitter; parameter_value_pairs...)

    (fitter::Fitter) |> fix!(; parameter_value_pairs...)

For each `{parameter => value}` pair in `parameter_value_pairs`, fixes
`parameter` to `value` when fitting, treating it as a constant. Returns
`fitter` so that similar calls can be chained together.
"""
@partially_applicable function fix!(fitter::Fitter; parameter_value_pairs...)
    for (parameter, value) in parameter_value_pairs
        fix!(fitter._parameters[parameter], value)
    end

    null_results!(fitter)

    fitter
end


function fix!(parameter::ModelParameter, value)
    parameter = FixedParameter(parameter.position, value)
end


# TODO: test `guess!`
"""
    guess!(fitter::Fitter, values::Dict{Symbol, AbstractFloat})

    (fitter::Fitter) |> guess!(values::Dict{Symbol, AbstractFloat})

    guess!(fitter::Fitter, values::Array{AbstractFloat, 1})

    (fitter::Fitter) |> guess!(values::Array{AbstractFloat, 1})

    guess!(fitter::Fitter; parameter_value_pairs...)

    (fitter::Fitter) |> guess!(; parameter_value_pairs...)

Set the initial guesses used to fit the free parameters of `fitter`.
"""
@partially_applicable function guess!(
        fitter::Fitter, values::Dict{Symbol, AbstractFloat})

    for (k, v) in values
        parameter = fitter._parameters[k]
        if isa(parameter, FreeParameter)
            parameter.value = v
        else
            msg = "$(k) is a fixed parameter. Its value can be set using " *
                  "`fix!`, or it can be freed using `free!`"
            warn(msg)
        end
    end

    fitter
end


@partially_applicable function guess!(
        fitter::Fitter, values::Array{AbstractFloat, 1})

    free_parameters =
        [k for (k, v) in fitter._parameters if isa(v, FreeParameter)]

    if length(values) ≠ length(free_parameters)
        msg = "If supplied as an Array, `values` must contain exactly one " *
              "entry for each free parameter associated with `fitter`."
        warn(msg)
    end

    guess!(Dict((p, v) for (p, v) in zip(free_parameters, values)))
end


@partially_applicable function guess!(fitter::Fitter; parameter_value_pairs...)
    guess!(fitter, parameter_value_pairs)
end

"""
    guesses(fitter::Fitter)

    guesses(model_parameters::ModelParameters)

Returns the initial guesses (or, for fixed parameters, the values) of
all fit parameters associated with `fitter` or `model_parameters`.
"""
function guesses(model_parameters::ModelParameters)
    guesses = ones(length(model_parameters))
    for val in values(model_parameters)
        guesses[val.position] = val.value
    end

    guesses
end


guesses(fitter::Fitter) = guesses(fitter._parameters)


"""
    n_free_parameters(fitter::Fitter)

    n_free_parameters(model_parameters::ModelParameters)

Returns the number of free (non-constant) parameters associated with
`fitter` or `model_parameters`.
"""
function n_free_parameters(model_parameters::ModelParameters)
    length([v for v in values(model_parameters) if isa(v, FreeParameter)])
end


n_free_parameters(fitter::Fitter) = n_free_parameters(fitter._parameters)


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
        msg = "xdata and ydata must have the same number of data"
        throw(BadDataException(msg))
    end

    if typeof(eydata) <: Number
        eydata = eydata * ones(xdata)
    elseif length(eydata) ≠ n_data
        msg = "eydata must be broadcastable to the size of xdata and ydata"
        throw(BadDataException(msg))
    end

    dataframe = DataFrame(Any[xdata, ydata, eydata], [:x, :y, :y_err])

    set_data!(fitter, dataframe)
end


@partially_applicable function set_data!(
        fitter::Fitter, dataframe::DataFrame,
        xvar=nothing, yvar=nothing, eyvar=nothing)
    if (size(dataframe, 2) ≠ 3)
        msg = "Exactly 3 columns of data must be supplied."
        throw(BadDataException(msg))
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
    fit!(fitter::Fitter; kwargs...)

    (fitter::Fitter) |> fit!(; kwargs...)

Fits the model function of `fitter` to the associated data. Updates the
settings of `fitter` from the values given in `kwargs` before fitting.
Returns `fitter` so that similar calls can be chained together.
"""
@partially_applicable function fit!(fitter::Fitter; kwargs...)
    if size(fitter.data, 1) == 0
        msg = "All xdata, ydata, and eydata must be set before calling `fit!`."
        throw(BadDataException(msg))
    end

    set!(fitter; kwargs...)

    fit_mask = data_mask(fitter)
    xdata_fit = xdata(fitter)[fit_mask]
    ydata_fit = ydata(fitter)[fit_mask]
    eydata_fit = eydata(fitter)[fit_mask]

    all_params = sort(
        collect(keys(fitter._parameters)),
        by=(k -> fitter._parameters[k].position))

    fitting_params = filter(
        (k -> isa(fitter._parameters[k], FreeParameter)), all_params)

    if isempty(fitting_params)
        msg = "No free parameters! Cannot fit."
        throw(CannotFitException(msg))
    end

    fitting_constants = Dict{Symbol, AbstractFloat}(
        [(key, val.value) for (key, val) in fitter._parameters if isa(val, FixedParameter)])

    auxiliary_fitting_function = eval(
        Expr( :function
            , Expr( :tuple
                  , :fitter
                  , fitter[:xvar]
                  , fitting_params...)
            , Expr( :block
                  , [Expr(:(=), k, v) for (k, v) in fitting_constants]...
                  , Expr( :call
                        , :(fitter._f_fitting)
                        , fitter[:xvar]
                        , Expr( :vect
                              , [k for k in all_params]...)))))

    fitting_function(x, p) = auxiliary_fitting_function(fitter, x, p...)

    guesses = [fitter._parameters[k].value for k in fitting_params]

    weights = 1 ./ abs(eydata_fit)
    fit_results = curve_fit(
        fitting_function, xdata_fit, ydata_fit, weights, guesses)

    if fit_results.converged
        fitter._converged = true

        params = fit_results.param
        param_errors = estimate_errors(fit_results, fitter[:error_range])

        for (i, (param, param_error)) in enumerate(zip(params, param_errors))
            fitter._parameters[fitting_params[i]].fit_value =
                Nullable{AbstractFloat}(params[i])
            fitter._parameters[fitting_params[i]].fit_uncertainty =
                Nullable{AbstractFloat}(param_errors[i])
        end

        fitter._covariance = estimate_covar(fit_results)
        fitter._residuals = Nullable{Array}(-fit_results.resid)

        if fitter[:autoplot]
            plot!(fitter)
        end
    else
        fitter._converged = false

        msg = "Fit did not converge."
        warn(msg)
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
        msg = "All xdata, ydata, and eydata must be set " *
              "in order to calculate residuals."
        throw(BadDataException(msg))
    end

    resids = []
    if isempty(params)
        if fitter._converged
            resids = get(fitter._residuals)
        else
            msg = "Fit must converge before residuals can be accessed."
            throw(NoResultsException(msg))
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

    ndof = countnz(data_mask(fitter)) - n_free_parameters(fitter)

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
        if fitter._converged
            params = ones(length(fitter._parameters))
            for val in values(fitter._parameters)
                if isa(val, FixedParameter)
                    params[val.position] = val.value
                else
                    params[val.position] = get(val.fit_value)
                end
            end
        else
            msg = "Parameters must be explicitly supplied."
            throw(NoResultsException(msg))
        end
    end
    fitter._f_fitting(x, params)
end
