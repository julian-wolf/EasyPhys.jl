EasyPhys.jl
===========

The EasyPhys package is a small library written to simplify some of the tasks that are repeated frequently when doing physics stuff. So far, it's very minimal.

Functionality is largely build on top of [LsqFit.jl](https://github.com/JuliaOpt/LsqFit.jl) and [PyPlot.jl](https://github.com/JuliaPy/PyPlot.jl) and has been inspired by the [Spinmob](https://github.com/Spinmob/spinmob) analysis and plotting package.

[![Build Status](https://travis-ci.org/julian-wolf/EasyPhys.jl.svg)](https://travis-ci.org/julian-wolf/EasyPhys.jl)

Usage
-----

Fitting is provided by the `Fitter` type and by the associated methods `set_data!`
and `fit!`.

    julia> using EasyPhys

    julia> fitter = Fitter((x, a, b) -> a .* x .+ b);

    julia> set_data!(fitter, [1, 2, 3, 4], [0, 1, 3, 5], [0.5, 0.4, 0.8, 0.5]) |> fit!

TODO
----

A lot.
