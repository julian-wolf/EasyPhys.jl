
function _getmethod(m::Function)
    fmethods = methods(m).ms
    @assert length(fmethods) == 1
    fmethods[1]
end


"""
    number_of_arguments(m::Function)

Gives the number of arguments taken by `m`. Requires that
`m` is the only method belonging to its generic function.
"""
number_of_arguments(m::Function) = length(_getmethod(m).sig.parameters) - 1


"""
    argument_names(m::Function)

Gives the original names of all arguments taken by `m`. Requires
that `m` is the only method belonging to its generic function.
"""
argument_names(m::Function) = _getmethod(m).lambda_template.slotnames[2:end]
