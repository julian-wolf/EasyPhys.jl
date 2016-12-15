

"""
    number_of_arguments(method::Function)

Gives the number of arguments taken by `method`. Requires that
`method` is the only method belonging to its generic function.
"""
function number_of_arguments(method::Function)
    fmethods = methods(method).ms
    @assert length(fmethods) == 1

    length(fmethods[1].sig.parameters) - 1
end


"""
    argument_names(method::Function)

Gives the original names of all arguments taken by `method`. Requires
that `method` is the only method belonging to its generic function.
"""
function argument_names(method::Function)
    n_args = number_of_arguments(method)

    argtypes = repeat([Any]; outer=n_args)
    lowered_code = code_lowered(method, argtypes)[1]
    @assert lowered_code.nargs - 1 == n_args

    lowered_code.slotnames[2:end]
end
