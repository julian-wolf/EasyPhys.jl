
VERSION ≥ v"0.4" && __precompile__()

module EasyPhys

import Base.getindex
import Base.setindex!
import Base.show

export plt,
       Fitter,
       set!,
       set_data!,
       fit!,
       results,
       parameter_errors,
       parameter_covariance,
       studentized_residuals,
       reduced_χ²,
       apply_f,
       plot!

include("utilities.jl")
include("data.jl")
include("fitter.jl")
include("plot.jl")

end
