
VERSION ≥ v"0.4" && __precompile__()

module EasyPhys

export plt,
       Fitter,
       set!,
       set_data!,
       free!,
       fix!,
       apply_mask!,
       ignore_outliers!,
       fit!,
       parameter_covariance,
       studentized_residuals,
       reduced_χ²,
       apply_f,
       plot!

include("utilities.jl")
include("fitter.jl")
include("plot.jl")

end
