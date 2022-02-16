
# These aren't actually regexes
# If it's an Array{String}, it's [before group, inside capture group, after capture group]
const typeRegexes = Dict{Type,Union{String,Array{String}}}(
    # ! Note for numeric types: Size isn't checked!
    # ! Will fail if a user enters a really large number.
    # ! Will fail if a parameter is actually an abstract numeric type.
    # ! (`parse` does not work on abstract numeric types)
    # ! Having the abstract classes and checking by <:
    # ! Allows a large range of numeric types to be used.
    # There is not one for a higher type because there is no reason.
    # Also, parse does not allow `im` by default, so no imaginary numbers.
    Integer => "\\d+",
    AbstractFloat => "\\d+(\\.\\d+)?",
    Bool => "true|false|yes|no",
    String => ["\"?", "[^\"]+", "\"?"], #string needs special treatment
    User => "@\\w+:[a-zA-z-]+\\.[a-zA-z-\\.]+",
    Any => "\\S+" # A string of anything without spaces. Please type your functions.
)
const typeRegexPrecedence = []



function ArgParse(_::Type{Bool}, s::AbstractString)
    l = lowercase(string(s))
    if l ∈ ["true", "yes"]
        return true
    elseif l ∈ ["false", "no"]
        return false
    end
    # this should never throw
    throw("$s is not a boolean value")
end

function ArgParse(_::Type{User}, s::AbstractString)
    return User(s)
end

function ArgParse(_::Type{String}, s::AbstractString)
    return string(s)
end

function ArgParse(_::Type{Any}, s::AbstractString)
    return string(s)
end

# If there is no special method, use the base parse.
function ArgParse(typ::Type, s::AbstractString)
    return parse(typ, s)
end

function count_supertypes(typ::DataType)
    c = 0
    while typ != Any
        # This should not show an error, it works.
        typ = Base.supertype(typ)
        c += 1
    end
    c
end

function generateTypePrecedence()
    if length(typeRegexPrecedence) == 0
        for type in keys(typeRegexes)
            push!(typeRegexPrecedence, (count_supertypes(type), type))
        end
    end
    sort!(typeRegexPrecedence, by = x -> x[1], rev = true)
end

generateTypePrecedence()

function addTypeRegex!(t::Type, r::String)
    haskey(typeRegexes, t) && debug("WARNING- redefining regex for $t")
    typeRegexes[t] = r
    push!(typeRegexPrecedence, (count_supertypes(t), t))
    sort!(typeRegexPrecedence, by = x -> x[1], rev = true)
end

function ParamRegex(r::String, name::String)
    "(?<$name>$r)"
end

function ParamRegex(r::Array{String}, name::String)
    #let the index errors go up if smth is wrong.
    "$(r[1])$(ParamRegex(r[2],name))$(r[3])"
end

function TypeRegex(t::Type, name::String)
    for (_, typ) in typeRegexPrecedence
        if t <: typ # Return the regex for the first type that matches.
            return ParamRegex(typeRegexes[typ], name)
        end
    end
    throw("No valid regixification found for type $t")
end
