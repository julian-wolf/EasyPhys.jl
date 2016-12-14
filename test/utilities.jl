
f(x, a, b) = a.*x .+ b

@test number_of_arguments(f) == 3

argnames = argument_names(f)
for argname ∈ [:x, :a, :b]
    @test argname ∈ argnames
end
