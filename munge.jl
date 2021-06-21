using CSV
using Dates
using DataFrames
using Missings
using Query
using TimeZones
using PlotlyJS
using Plots
using StatsBase
using StatsPlots

const COLUMNS = [
    "Time",
    "Temperature / °C",
    "Humidity / %",
    "Dew point / °C",
    "Pressure / mBar",
    "Wind speed / knots",  # Mean?
    "Wind direction",
    "Sun / hours",
    "Rain / mm",
    "Start",  # ???
    "Max Wind Speed / knots",
]

function get_path(day::Date)::String
    return joinpath("daily-text", Dates.format(day, "yyyy_mm_dd"))
end

function get_frame(date_range)::DataFrame
    frame = nothing
    for date in date_range
        path = get_path(date)
        this_frame = CSV.File(path; header=COLUMNS, comment="#") |> DataFrame

        # Use first occurrence... seems like there's something iffy in the raw data around
        # DST changes in any case!
        insertcols!(
            this_frame,
            1,
            :DateTime => ZonedDateTime.(date .+ this_frame[!, :Time], tz"Europe/London", 1)
        )
        # this_frame[!, :Date] .= date
        if isnothing(frame)
            frame = this_frame
        else
            frame = vcat(frame, this_frame)
        end
    end

    # Check that we haven't been bitten by DST ambiguities.
    @assert nrow(frame) == length(unique(frame[!, :DateTime]))

    # Remove columns that are non-useful.
    frame = frame[!, Not([:Time, :Start])]

    # Ensure all columns have no missing values.
    return disallowmissing(frame)
end


"""Make a data frame summarising the weather on each day."""
function summarise(frame::AbstractDataFrame)::DataFrame
    frame[!, :Date] = frame[!, :DateTime].|> zdt -> Date(zdt.utc_datetime)
    gdf = groupby(frame, :Date)

    summaries = []
    for (key, group) in zip(keys(gdf), gdf)
        temp = group[!, "Temperature / °C"]
        pressure = group[!, "Pressure / mBar"]
        humidity = group[!, "Humidity / %"]

        push!(
            summaries,
            (
                date=key[:Date],
                temp_max=maximum(temp),
                temp_min=minimum(temp),
                temp_mean=mean(temp),
                pressure_max=maximum(pressure),
                pressure_min=minimum(pressure),
                pressure_mean=mean(pressure),
                humidity_max=maximum(humidity),
                humidity_min=minimum(humidity),
                humidity_mean=mean(humidity),
            )
        )
    end
    return summaries |> DataFrame
end


frame = get_frame(Date(2020, 1, 1):Day(1):Date(2021, 6, 19))

plotlyjs()
Plots.plot(
    frame[!, :DateTime],
    # frame[!, "Rain / mm"];
    # frame[!, "Sun / hours"];
    frame[!, "Humidity / %"];
    linetype=:steppost,
    ticks=:native
)


summary_frame = summarise(frame)

@df summary_frame Plots.plot(
    :date,
    [:humidity_min :humidity_mean :humidity_max];
    linetype=:steppost,
    ticks=:native,
    ylabel="Humidity / %",
)
Plots.savefig("humidity.png")

@df summary_frame Plots.plot(
    :date,
    [:temp_min :temp_mean :temp_max];
    linetype=:steppost,
    ticks=:native,
    ylabel="Temperature / °C",
)
Plots.savefig("temperature.png")

@df summary_frame Plots.plot(
    :date,
    [:pressure_min :pressure_mean :pressure_max];
    linetype=:steppost,
    ticks=:native,
    ylabel="Pressure / mBar",
)
Plots.savefig("pressure.png")

summary_frame |> CSV.write("summary.csv")
