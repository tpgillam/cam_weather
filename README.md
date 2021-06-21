Source: https://www.cl.cam.ac.uk/research/dtg/weather/index-daily-text.html

1. Download history of weather data (`weather.tar.gz`) from source above.
1. Extracting, should give a directory `daily-text`, containing one file per day.
1. Running `munge.jl` will produce a file, `summary.csv`, as well as some plots.

Note that running the experiment requires Julia 1.6. From a shell in this directory, one should be able to do the following to install dependencies and run
everything:

```
> julia --project=.
julia> using Pkg; Pkg.instantiate()
julia> include("munge.jl")
```