EasyPhys.jl
===========

The EasyPhys package is a small library written to simplify some of the tasks that are repeated frequently when doing physics stuff.
So far, it's very minimal.

Functionality is largely build on top of [LsqFit.jl](https://github.com/JuliaOpt/LsqFit.jl) and [PyPlot.jl](https://github.com/JuliaPy/PyPlot.jl) and has been inspired by the [Spinmob](https://github.com/Spinmob/spinmob) analysis and plotting package.

[![EasyPhys](http://pkg.julialang.org/badges/EasyPhys_0.5.svg)](http://pkg.julialang.org/?pkg=EasyPhys)
[![EasyPhys](http://pkg.julialang.org/badges/EasyPhys_0.6.svg)](http://pkg.julialang.org/?pkg=EasyPhys&ver=0.6)

[![Build Status](https://travis-ci.org/julian-wolf/EasyPhys.jl.svg)](https://travis-ci.org/julian-wolf/EasyPhys.jl)
[![Coverage Status](https://coveralls.io/repos/github/julian-wolf/EasyPhys.jl/badge.svg?branch=master)](https://coveralls.io/github/julian-wolf/EasyPhys.jl?branch=master)

Installation
------------

EasyPhys is available through Julia's built-in package manager, and can be installed by running `Pkg.add("EasyPhys.jl")` at the Julia prompt.
This will automatically install any necessary dependencies.

Usage
-----

Fitting is provided by the `Fitter` type and by the associated methods `set_data!`
and `fit!`.

    julia> using EasyPhys

    julia> model(x, a, b) = a .* exp(-b .* x);

    julia> xdata = linspace(0,10,100); ydata = model(xdata, 1.0, 2.0) + 0.01*randn(length(xdata)); eydata = 0.01;

    julia> fitter = Fitter(model) |> set_data!(xdata, ydata, eydata) |> fit!

TODO
----

A lot.
