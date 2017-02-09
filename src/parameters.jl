
"""
Describes a single parameter to a model function.
"""
abstract ModelParameter


typealias ModelParameters Dict{Symbol, ModelParameter}


"""
Describes a free (non-constant) parameter to a model function.
"""
type FreeParameter <: ModelParameter

    "Index of the parameter in the function's argument list."
    position::Integer

    "The initial guess used for fitting."
    value::AbstractFloat

    "Best-fit value of the parameter, if it exists."
    fit_value::Nullable{AbstractFloat}

    "Uncertainty on the best-fit value of the parameter, if it exists."
    fit_uncertainty::Nullable{AbstractFloat}

    """
        FreeParameter(position, guess)

    Creates a new FreeParameter object with indexed at `position` with
    initial guess `guess`.
    """
    function FreeParameter(position, guess)
        instance = new()

        instance.position = position
        instance.value    = guess

        instance.fit_value       = Nullable{AbstractFloat}()
        instance.fit_uncertainty = Nullable{AbstractFloat}()

        instance
    end

end


"""
Describes a fixed (constant) parameter to a model function.
"""
type FixedParameter <: ModelParameter

    "Index of the parameter in the function's argument list."
    position::Integer

    "The value to which the parameter is fixed."
    value::AbstractFloat

    """
        FixedParameter(position, value)

    Creates a new FixedParameter object with indexed at `position` with
    constant value `value`.
    """
    function FixedParameter(position, value)
        instance = new()

        instance.position = position
        instance.value    = value

        instance
    end

end

