# Munge the MET office data, downloaded from:
#   https://www.metoffice.gov.uk/pub/data/weather/uk/climate/stationdata/cambridgedata.txt

using DataFrames
using Measures
using MetOfficeStationData
using Plots

short_name = "cambridge"
# short_name = "oxford"

metadata = MetOfficeStationData.get_station_metadata()
# display(metadata)

display_name = only(eachrow(filter(:short_name => ==(short_name), metadata)))[:name]

frame = MetOfficeStationData.get_frame(short_name)

p1 = begin
    plot(;
        xlabel="Month",
        ylabel="Cumulative rainfall / mm",
        title=display_name,
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

yearly_rain = dropmissing(combine(groupby(frame, :yyyy), :rain => sum => :rain))
display(first(sort(yearly_rain, :rain; rev=true), 5))

p2 = plot(
    yearly_rain[!, :yyyy],
    yearly_rain[!, :rain];
    xlabel="Year",
    ylabel="Annual rainfall / mm",
    title=display_name,
    legend=nothing,
)

display(plot(p1, p2; size=(800, 400), margin=3mm))

