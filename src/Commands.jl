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
function runcmds(client::Client, info::EventInfo)
    messagebody = info.content["body"]
    @debug "Looking for commands to run."
    # need to run this in try-catch because commands are user-provided code that can error.
    try
        for cmd in client.commands
            if occursin(cmd.functionNameMatch, messagebody)
                @debug "Matches function: $(cmd.functionNameMatch), looking for subcommand match..."
                for subcmd in cmd.calls
                    @debug "Found subcommand match"
                    if occursin(subcmd.invocation, messagebody)
                        matches = match(subcmd.invocation, messagebody)
                        args = []
                        p = 1
                        for a in subcmd.argtypes[2:end]
                            # Add parsed args to the args.
                            push!(args, argparse(a, matches["p$p"]))
                            p += 1
                        end
                        @debug "Got args, executing."
                        subcmd.fn(info, args...)
                        #once a command has been executed, stop looking.
                        return
                    end
                end
                # Should send some sort of notice that it failed.
                sendmessage!(client, info.room, cmd.help)
                # don't keep looking.
                return
            end
        end
    catch e
        @warn "A command errored"
        if client.errors
            throw(e)
        end
    end
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
function command!(
    fn::Function,
    client::Client,
    invocation::String;
    takeExtra::Bool = false,
    friendlyname::String = "",
    description::String = "A command.",
    help::String = "そんなのないよ？"
)
    command!(fn, client, Regex(neutralizeregexsymbols(invocation)), takeExtra = takeExtra, friendlyname = friendlyname, description = description, help = help)
end

function command!(
    fn::Function,
    client::Client,
    invocation::Regex;
    takeExtra::Bool = false,
    friendlyname::String = "",
    description::String = "A command.",
    help::String = "そんなのないよ？"
)
    # Make sure that any symbols in the command's invocation aren't interpreted as regex control characters.
    fnTakesTheseArgs = first(methods(fn)).sig.types[2:end]

    #First arg MUST be eventInfo
    if fnTakesTheseArgs[1] <: EventInfo || fnTakesTheseArgs[1] == Any
    else
        throw(ArgumentError("Command functions must take EventInfo as first parameter"))
    end

    #determine precedence level
    isPlain = occursin(invocation, invocation.pattern)
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

    #function name is a regex to match the first part.
    fnname = Regex("^$(invocation.pattern)", "i")
    #advanced stuff
    subcmd = SubCommand(precedence, invoregex, collect(fnTakesTheseArgs), fn)
    #check if exists
    possi = filter(x -> x.functionNameMatch == fnname, client.commands)
    if isempty(possi)
        #add a new command (without the string extras, those come later) and sort! the commands.
        prec = isPlain ? 1 : 2 #this is stupid, but, reduce precedence among Commands and make it the usual system among subcommands
        na = isempty(friendlyname) ? invocation.pattern : friendlyname
        cmd = Command(prec, fnname, [subcmd], na, description, help)
        push!(client.commands, cmd)
        sort!(client.commands, by = x -> x.precedence)
        @debug "Added command $fnname with subcommand $invoregex"
    else
        cmd = first(possi)
        push!(cmd.calls, subcmd)
        #need to sort the subcommands
        sort!(cmd.calls, by = x -> x.precedence)
        @debug "Added subcommand $invoregex to command $fnname"
    end

    #addcommand!(fn, client, invoregex, precedence)
end
