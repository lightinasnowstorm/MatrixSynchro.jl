#precedence is from low to high, low check first
"""
How much precedence is given to different types of command. Lower is checked earlier.
More exact commands are preferred over more general ones.
"""
module CommandPrecedence
const exact = 1
const command_with_params = 2
const specific_regex = 3
const command_with_params_and_more = 4
const command_and_more = 5
const just_more = 6
end

"""
    runcmds(info)

(internal)
Runs the command most relating to a received message, or none if no commands match.
"""
function runcmds(info::EventInfo)
    lc = info.content["body"]
    @debug "Looking for commands to run."
    # this hurts me inside
    for (_, invocation) in info.client.commandPrecedence
        if occursin(invocation, lc)
            @debug "executing command: $invocation"
            fn = info.client.commands[invocation]
            argTypes = first(methods(fn)).sig.types[3:end]
            matches = match(invocation, lc)
            args = []
            p = 1
            for a in argTypes
                # Add parsed args to the args.
                push!(args, argparse(a, matches["p$p"]))
                p += 1
            end
            @debug "Got args, executing."
            # splat the args into the function.
            # If there are no args, no args are sent to it.
            fn(info, args...)
            # Once a command has been called, don't need to look for another.
            return
        end
    end
end

"""
    addcommand!(command function, client, regex invocation, precedence)

(internal)
Adds a function as a command.
"""
function addcommand!(fn::Function, client::Client, invo::Regex, precedence::Int)
    haskey(client.commands, invo) && @warn "redefining $invo"
    client.commands[invo] = fn
    push!(client.commandPrecedence, (precedence, invo))
    sort!(client.commandPrecedence, by = x -> x[1])
    @debug "Added command $invo"
end

"""
    neutralizeregexsymbols(str)

(internal)
Escapes all characters that have a meaning in regex so that a string containing them can be used as a regex that matches itself.
"""
function neutralizeregexsymbols(s::String)
    function neutralizeregexchar(c::Char)
        # Escape all special characters with a regex meaning with a backslash.
        if c ∈ ['\\', '^', '$', '{', '}', '[', ']', '(', ')', '.', '*', '+', '?', '|', '<', '>', '-', '&']
            "\\$c"
        else
            c
        end
    end
    join(map(neutralizeregexchar, collect(s)))
end

"""
    command!(function, client, invocation; takeExtra = false)

Creates a command from a function. The arguments that the function takes are used to construct the command's arguments.

`function` - The function to run when the command is invoked.

`client` - The client to add the command to.

`invocation` - The command's "name", that is used to call it by users.

`takeExtra` - Whether the command can have extra text after the end of its arguments.
"""
function command!(fn::Function, client::Client, invocation::String; takeExtra::Bool = false)
    command!(fn, client, Regex(neutralizeregexsymbols(invocation)), takeExtra = takeExtra)
end

function command!(fn::Function, client::Client, invocation::Regex; takeExtra::Bool = false)
    # Make sure that any symbols in the command's invocation aren't interpreted as regex control characters.
    fnTakesTheseArgs = first(methods(fn)).sig.types[2:end]

    #First arg MUST be eventInfo
    if fnTakesTheseArgs[1] <: EventInfo || fnTakesTheseArgs[1] == Any
    else
        throw(ArgumentError("Command functions must take EventInfo as first parameter"))
    end

    #determine precedence level
    isPlain = occursin(invocation,invocation.pattern)
    hasArgs = length(fnTakesTheseArgs) > 1
    precedence = Dict{Tuple,Int}(
        # Neither args or extra.
        (false, false, false) => CommandPrecedence.specific_regex,
        (true, false, false) => CommandPrecedence.exact,
        # These have args but no extra.
        (true, true, false) => CommandPrecedence.command_with_params,
        (false, true, false) => CommandPrecedence.command_with_params_and_more,
        # Args and extra.
        (true, true, true) => CommandPrecedence.command_and_more,
        (false, true, true) => CommandPrecedence.command_and_more,
        # Just extra, no args.
        (true, false, true) => CommandPrecedence.just_more,
        (false, false, true) => CommandPrecedence.just_more
    )[(isPlain, hasArgs, takeExtra)]

    invoregexbuilder = [invocation.pattern]

    p = 1
    # For each of the other arguments of the function
    for arg in fnTakesTheseArgs[2:end]
        # Get the regex for the type and add it to the builder.
        push!(invoregexbuilder, typeregex(arg, "p$p"))
        # p<n> is a capture group in the regex for this argument.
        p += 1
    end

    # Without take extra, it has $ to make sure it ends there.
    invoregex = Regex("^$(join(invoregexbuilder,"\\s+"))$(takeExtra ?  "" : "\$")", "i")

    addcommand!(fn, client, invoregex, precedence)
end
