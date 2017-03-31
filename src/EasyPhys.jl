
__precompile__()

module EasyPhys

export plt,
       Fitter,
       set!,
       set_data!,
       free!,
       fix!,
       guess!,
       apply_mask!,
       ignore_outliers!,
       fit!,
       parameter_covariance,
       studentized_residuals,
       reduced_χ²,
       apply_f,
       plot,
       plot!

using Compat
import Compat.String

include("utilities.jl")
include("parameters.jl")
include("fitter.jl")
include("plot.jl")

end
