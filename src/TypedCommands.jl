
# These aren't actually regexes
# If it's an Array{String}, it's [before group, inside capture group, after capture group]
const typeRegexes = Dict{Type,Union{String,Array{String}}}(
    # ! Note for numeric types: Size isn't checked!
    # ! Will fail if a user enters a really large number.
    # ! Will default to Any if the type isn't in here!
    # ! Will fail if a parameter is actually an abstract numeric type.
    # ! (`parse` does not work on abstract numeric types)
    # ! Having the abstract classes and checking by <:
    # ! Allows a large range of numeric types to be used.
    # There is not one for a higher type because there is no reason.
    # Also, parse does not allow `im` by default, so no imaginary numbers.
    Integer => "\\d+",
    AbstractFloat => "\\d+(\\.\\d+)?",
    Bool => "true|false|yes|no",
    User => "@\\w+:[a-zA-z-]+\\.[a-zA-z-\\.]+"
)

function argparse(_::Type{Bool}, s::AbstractString)
    l = lowercase(string(s))
    if l ∈ ["true", "yes"]
        return true
    elseif l ∈ ["false", "no"]
        return false
    end
    # this should never throw
    throw(ArgumentError("$s is not a boolean value"))
end

function argparse(_::Type{User}, s::AbstractString)
    return User(s)
end

function argparse(_::Type{String}, s::AbstractString)
    return string(s)
end

function argparse(_::Type{Any}, s::AbstractString)
    return string(s)
end

# If there is no special method, use the base parse.
function argparse(typ::Type, s::AbstractString)
    return parse(typ, s)
end

# Generate the regex-giving method for the types that have a consistent one.
for typ in keys(typeRegexes)
    eval(quote
        function typeregex(_::Type{T}, name::String) where {T<:$typ}
            "(?<$name>$(typeRegexes[$typ]))"
        end
    end)
end

# String needs a special function because it has quotes around the capture group.
function typeregex(_::Type{String}, name::String)
    "\"?(?<$name>[^\"]+)\"?"
end

# This is for Any. Types are very specific.
function typeregex(_::Type, name::String)
    "(?<$name>\\S+)" # A string of anything without spaces. Please type your functions.
end
