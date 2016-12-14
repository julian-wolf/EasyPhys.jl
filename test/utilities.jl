
f(x, a, b) = a.*x .+ b

@test EasyPhys.number_of_arguments(f) == 3

argnames = EasyPhys.argument_names(f)
for argname ∈ [:x, :a, :b]
    @test argname ∈ argnames
end
