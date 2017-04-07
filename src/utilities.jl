
import Base.@__doc__
import Base.Meta.isexpr
import Base.isidentifier


"""
    number_of_arguments(method::Function)

    number_of_arguments(method::Method)

Gives the number of arguments taken by `method`. If a generic function
is supplied, it must be associated with exactly one method.
"""
function number_of_arguments(method::Function)
    fmethods = methods(method).ms
    @assert length(fmethods) == 1

    number_of_arguments(first(fmethods))
end


number_of_arguments(method::Method) = length(method.sig.parameters) - 1


"""
    argument_names(method::Function)

Gives the original names of all arguments taken by `method`. Requires
that `method` is the only method belonging to its generic function.
"""
function argument_names(method::Function)
    n_args = number_of_arguments(method)

    argtypes = repeat([Any]; outer=n_args)
    lowered_code = first(code_lowered(method, argtypes))

    arguments = filter(isidentifier, lowered_code.slotnames[2:end])
    @assert length(arguments) == number_of_arguments(method)

    arguments
end


"""
    @partially_applicable f(x, args...; kwargs...) = ()

    @partially_applicable function g(x, args...; kwargs...) end

Pretty hacky. When applied to a function definition `f` of a function with
more than one argument, defines two methods on the function: one equivalent
to that defined by `f`, and one that takes one fewer argument than `f`,
amounting to all but the first argument, and partially applies them,
returning the resulting single-parameter

# Examples

```jldoctest
julia> @partially_applicable f(x, a, b) = a*x + b
f (generic function with 2 methods)

julia> f(28, 38, 273) == 28 |> f(38, 273)
true

julia> @partially_applicable g(x; kwargs...) = (println(kwargs); x*5)
g (generic function with 2 methods)

julia> g(2, sortaneat=:yes) == 2 |> g(sortaneat=:yes)
Any[(:sortaneat,:yes)]
Any[(:sortaneat,:yes)]
true
```
"""
macro partially_applicable(func)
    func_original = copy(func)

    is_parameter(x) = isa(x, Symbol) || isexpr(x, :(::))

    (var_index, var) =
        [(i, x) for (i, x) in enumerate(func.args[1].args) if is_parameter(x)][2]

    deleteat!(func.args[1].args, var_index)

    if isa(var, Expr)
        var = var.args[1]
    end

    func.args[2] = Expr(:(->), var, func.args[2])

    quote
        @__doc__ $(esc(func_original))
                 $(esc(func))
    end
end
