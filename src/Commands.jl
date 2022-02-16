include("MatrixClient.jl")
include("TypedCommands.jl")
include("DebugPrint.jl")


#precedence is from low to high, low check first
module CommandPrecedence
const Exact = 1
const CommandWithParams = 2
const SpecificRegex = 3
const ThisCommandWithParamsAndAnythingAfter = 4
const ThisAndAnythingAfter = 5
end

function runCmds(eventData::EventInfo)
    lc = eventData.content["body"]
    debug("Looking for commands to run.")
    # this hurts me inside
    for (_, invocation) in eventData.client.commandPrecedence
        if occursin(invocation, lc)
            debug("executing command: $invocation")
            fn = eventData.client.commands[invocation]
            argTypes = first(methods(fn)).sig.types[3:end]
            matches = match(invocation, lc)
            args = []
            p = 1
            for a in argTypes
                # Add parsed args to the args.
                push!(args, ArgParse(a, matches["p$p"]))
                p += 1
            end
            debug("Got args, executing.")
            # splat the args into the function.
            # If there are no args, no args are sent to it.
            fn(eventData, args...)
            # Once a command has been called, don't need to look for another.
            return
        end
    end
end

# ! Will be deprecated when commands are merged into Sync!
function guaranteeCommandEvent!(client::Client)
    if !haskey(client.callbacks, Event.message) || runCmds ∉ client.callbacks[Event.message]
        on!(runCmds, client, Event.message)
    end
end

function addCommand!(fn::Function, client::Client, invo::Regex, precedence::Int = 999)
    guaranteeCommandEvent!(client)
    haskey(client.commands, invo) && debug("WARNING: redefining $invo")
    client.commands[invo] = fn
    push!(client.commandPrecedence, (precedence, invo))
    sort!(client.commandPrecedence, by = x -> x[1])
    debug("Added command $invo")
end

function hasSymbols(s::String)
    occursin(r"\/|\>|\,|\.|\[|\]|\{|\}|\(|\)|\\|\||\`|\~|\!|\@|\#|\$|\%|\^|\&|\*|\-|\=|\_|\+|\<|\>|\?|\'|\"", s)
end

function command!(fn::Function, client::Client, invocation::Regex)
    fnTakesTheseArgs = first(methods(fn)).sig.types[2:end]
    if fnTakesTheseArgs[1] <: EventInfo || fnTakesTheseArgs[1] == Any
    else
        throw("Command functions must take EventInfo as first parameter")
    end
    if length(fnTakesTheseArgs) > 1
        throw("A regex command must not take arguments.")
    end
    addCommand!(fn, client, invocation, CommandPrecedence.SpecificRegex)
end

function command!(fn::Function, client::Client, invocation::String; takeExtra::Bool = false)
    hasSymbols(invocation) && throw("Cannot use a symbols in a command name!")
    fnTakesTheseArgs = first(methods(fn)).sig.types[2:end]

    #First arg MUST be eventData
    if fnTakesTheseArgs[1] <: EventInfo || fnTakesTheseArgs[1] == Any
    else
        throw("Command functions must take EventInfo as first parameter")
    end

    #determine precedence level
    precedence = Dict{Tuple,Int}(
        (false, false) => CommandPrecedence.Exact,
        (false, true) => CommandPrecedence.ThisAndAnythingAfter,
        (true, false) => CommandPrecedence.CommandWithParams,
        (true, true) => CommandPrecedence.ThisCommandWithParamsAndAnythingAfter
    )[(length(fnTakesTheseArgs) == 1, takeExtra)]

    invoregexbuilder = [invocation]

    p = 1
    # For each of the other arguments of the function
    for arg in fnTakesTheseArgs[2:end]
        # Get the regex for the type and add it to the builder.
        push!(invoregexbuilder, TypeRegex(arg, "p$p"))
        # p<n> is a capture group in the regex for this argument.
        p += 1
    end

    # Without take extra, it has $ to make sure it ends there.
    invoregex = Regex("^$(join(invoregexbuilder,"\\s+"))$(takeExtra ?  "" : "\$")", "i")

    addCommand!(fn, client, invoregex, precedence)
end
