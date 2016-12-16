
@testset "utilities.jl" begin

f_test(x, a, b) = a.*x .+ b

@test EasyPhys.number_of_arguments(f_test) == 3

argnames_test = EasyPhys.argument_names(f_test)
for argname in [:x, :a, :b]
    @test argname ∈ argnames_test
end

EasyPhys.@partially_applicable g_test(x, a, b; kwargs...) = (a*x + b)
for x in 1:5, a in 6:10, b in 1:10
    @test g_test(x, a, b; test=true) == x |> g_test(a, b; test=false) == a*x + b
end

EasyPhys.@partially_applicable g_test(x; kwargs...) = (println(kwargs); 5*x)
@test g_test(2; test=:whocares) == 2 |> g_test(test=:doesntmatter) == 10

end
