
@testset "utilities.jl" begin

f_test(x, a, b) = a .* x .+ b

@test EasyPhys.number_of_arguments(f_test) == 3

@test EasyPhys.argument_names(f_test) == [:x, :a, :b]


EasyPhys.@partially_applicable g_test(x, a, b; kwargs...) = (a * x + b)
for x in 1:5, a in 6:10, b in 1:10
    @test g_test(x, a, b; test=true) == x |> g_test(a, b; test=false) == a * x + b
end

EasyPhys.@partially_applicable g_test(x; kwargs...) = (println(kwargs); 5*x)
@test g_test(2; test=:somearg) == (2::Int) |> g_test(test=:someotherarg) == 10

end
