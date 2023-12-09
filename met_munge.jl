# Munge the MET office data, downloaded from:
#   https://www.metoffice.gov.uk/pub/data/weather/uk/climate/stationdata/cambridgedata.txt

using CSV
using DataFrames
using Plots

_parse_value(::Missing) = missing
_parse_value(x::Number) = x
_parse_value(x::AbstractString) = parse(Float64, replace(x, "*" => ""))

frame = CSV.read(
    "cambridgedata_20231209.txt",
    DataFrame;
    header=[6],
    skipto=8,
    delim=' ',
    ignorerepeated=true,
)
frame = ifelse.(isequal.(frame, "---"), missing, frame)
# insertcols!(frame, 1, :date => Date.(frame[!, :yyyy], frame[!, :mm]))
# select!(frame, Not([:yyyy, :mm]))
select!(frame, Not([:Column8]))

for col in Tables.columnnames(frame)[2:end]
    frame[!, col] .= _parse_value.(frame[!, col])
end

begin
    plot(;
        xlabel="Month",
        ylabel="Cumulative rainfall / mm",
        title="Cambridge NIAB",
        legend=:topleft,
    )
    g = groupby(frame, :yyyy; sort=true)
    for (i, key) in enumerate(keys(g))
        year = only(key)
        df = g[key]
        # a = i / length(g)
        # c = RGBA(1 - a, 0.0, a, alpha)

        c, alpha, lw, ls, label = if i == length(g)
            :blue, 1, 3, :solid, year
        elseif i == (length(g) - 1)
            :purple, 1, 2, :dash, year
        elseif i == (length(g) - 2)
            :red, 1, 2, :dashdot, year
        elseif i == (length(g) - 3)
            :orange, 1, 2, :dashdotdot, year
        elseif i == (length(g) - 4)
            :grey, 0.3, 1, :solid, "<$(year + 1)"
        else
            :grey, 0.3, 1, :solid, nothing
        end

        plot!(
            vcat([0], df[!, :mm]),
            vcat([0], cumsum(df[!, :rain]));
            # df[!, :mm],
            # df[!, :tmax];
            lw,
            ls,
            c,
            alpha,
            label,
            xticks=1:12,
            yminorgrid=true,
        )
    end
    Plots.current()
end
