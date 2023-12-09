using CSV
using Dates
using DataFrames
using Missings
using Query
using TimeZones
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
    "Sun / hours",  # Cumulative, resets daily
    "Rain / mm",  # Cumulative, resets daily (? though some data looks suspicious)
    "Start",  # ? This looks like the time of day from which e.g. 'rain' & 'sun' are measured.
    "Max Wind Speed / knots",
]

function get_path(day::Date)::String
    return joinpath("daily-text", Dates.format(day, "yyyy_mm_dd"))
end

function _get_time(date::Date, raw_time, occurrence::Integer)
    return DateTime(ZonedDateTime(date + raw_time, tz"Europe/London", occurrence), UTC)
end

function _to_datetimes(date::Date, raw_times)
    times = DateTime[]
    sizehint!(times, length(raw_times))
    for raw_time in raw_times
        time = _get_time(date, raw_time, 1)
        time = if !isempty(times) && last(times) >= time
            _get_time(date, raw_time, 2)
        else
            time
        end
        push!(times, time)
    end
    return times
end

function get_frame(date::Date)
    path = get_path(date)
    !isfile(path) && return missing
    frame = CSV.File(path; header=COLUMNS, comment="#") |> DataFrame

    # Use first occurrence... seems like there's something iffy in the raw data around
    # DST changes in any case!
    insertcols!(frame, 1, :DateTime => _to_datetimes(date, frame[!, :Time]))

    if nrow(frame) != length(unique(frame[!, :DateTime]))
        error("Bad times found on $date")
    end

    # Fix rainfall.
    if !(eltype(frame[!, "Rain / mm"]) <: Number)
        frame[!, "Rain / mm"] = parse.(Float64, replace(frame[!, "Rain / mm"], "*" => "0"))
    end

    # frame[!, :Date] .= date
    return frame
end

function get_frame(date_range::AbstractVector{Date})
    frame = nothing
    for date in date_range
        this_frame = get_frame(date)
        ismissing(this_frame) && continue
        frame = isnothing(frame) ? this_frame : vcat(frame, this_frame)
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
    frame[!, :Date] = frame[!, :DateTime] .|> zdt -> Date(zdt.utc_datetime)
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

# The date range to process. End points are inclusive.
# t_start = Date(2017, 1, 1)
# t_start = Date(1995, 6, 30)  # This is the first day with data
t_start = Date(2000, 1, 1)
t_end = Date(2023, 5, 6)

# Get one dataframe for the range specified above. This will put the data from all files
# into a single dataframe.
frame = get_frame(t_start:Day(1):t_end)

function _get_delta_rainfall(rain_mm::AbstractVector{<:AbstractFloat})
    result = Float64[]
    sizehint!(result, length(rain_mm))
    # Placeholder that indicates that we haven't had a previous value.
    prev_x = Inf
    for x in rain_mm
        if (isempty(result) || x < prev_x)
            push!(result, x)
        else
            push!(result, x - prev_x)
        end
        prev_x = x
    end
    return result
end

delta_rain = _get_delta_rainfall(frame[!, "Rain / mm"])

# Plot a long timeseries of all data we've processed above.
plotlyjs()  # Allow interactivity.
Plots.plot(
    frame[!, :DateTime],
    cumsum(delta_rain);
    # frame[!, "Sun / hours"];
    # frame[!, "Humidity / %"];
    linetype=:steppost,
    ticks=:native
)

# Aggregate the data into one row per day, keeping some small amount of information.
summary_frame = summarise(frame)

# Make a few plots of the summary data.
@df summary_frame Plots.plot(
    :date,
    [:humidity_min :humidity_mean :humidity_max];
    linetype=:steppost,
    ticks=:native,
    ylabel="Humidity / %"
)
Plots.savefig("humidity.png")

@df summary_frame Plots.plot(
    :date,
    [:temp_min :temp_mean :temp_max];
    linetype=:steppost,
    ticks=:native,
    ylabel="Temperature / °C"
)
Plots.savefig("temperature.png")

@df summary_frame Plots.plot(
    :date,
    [:pressure_min :pressure_mean :pressure_max];
    linetype=:steppost,
    ticks=:native,
    ylabel="Pressure / mBar"
)
Plots.savefig("pressure.png")

# Output the summary frame to disk (should be usable by a spreadsheet!)
summary_frame |> CSV.write("summary.csv")
