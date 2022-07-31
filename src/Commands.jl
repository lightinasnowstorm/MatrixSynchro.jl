# precedence is from low to high, low check first
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
    runcmds(client, info)

(internal)
Runs the command most relating to a received message, or none if no commands match.
"""
function runcmd(client::Client, info::EventInfo)
    messagebody = info.content["body"]
    @debug "Looking for commands to run."
    cmdindex = findfirst(c -> occursin(c.functionNameMatch, messagebody), client.commands)
    if cmdindex === nothing
        #There is no command, return.
        return
    end
    cmd = client.commands[cmdindex]
    @debug "Found a command to run, looking a valid subcommand..."
    subcmdindex = findfirst(sc -> occursin(sc.invocation, messagebody), cmd.calls)
    if subcmdindex === nothing
        # There is no valid call, give the help.
        sendmessage!(client, info.room, cmd.help)
        # and then return.
        return
    end
    @debug "Found a subcommand to run, executing..."
    subcmd = cmd.calls[subcmdindex]
    @async runsubcmd(client, info, cmd, subcmd)
end

"""
    runsubcmd(client, info, subcmd)

(internal)
Runs a specified subcommand on a message.
"""
function runsubcmd(client::Client, info::EventInfo, cmd::Command, subcmd::SubCommand)
    try
        messagebody = info.content["body"]
        # need to run this in try-catch because commands are user-provided code that can error.
        matches = match(subcmd.invocation, messagebody)
        args = []
        p = 1
        for a in subcmd.argtypes
            # Add parsed args to the args.
            push!(args, argparse(a, matches["p$p"]))
            p += 1
        end
        if subcmd.matchparam
            @debug "Got args (matchparam extra), executing..."
            subcmd.fn(info, matches, args...)
        else
            @debug "Got args, executing."
            subcmd.fn(info, args...)
        end
    catch e
        @warn "Executing $(subcmd.invocation) for $(info.sender) failed!"
        # send failure message.
        sendmessage!(client, info.room, cmd.onfailure)
        if client.errors
            @error e
            # ! thanks to async, this doesn't work anymore.
            throw(e)
        end
    end
end

"""
    neutralizeregexsymbols(str)

(internal)
Escapes all characters that have a meaning in regex so that a string containing them can be used as a regex that matches itself.
"""
function neutralizeregexsymbols(s::AbstractString)
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
    invocation::AbstractString;
    takeExtra::Bool = false,
    friendlyname::AbstractString = "",
    description::AbstractString = "A command.",
    help::AbstractString = "そんなのないよ？",
    onfail::AbstractString = "Command failed."
)
    command!(
        fn,
        client,
        Regex(neutralizeregexsymbols(invocation)),
        takeExtra = takeExtra,
        friendlyname = friendlyname,
        description = description,
        help = help,
        onfail = onfail
    )
end

function command!(
    fn::Function,
    client::Client,
    invocation::Regex;
    takeExtra::Bool = false,
    friendlyname::AbstractString = "",
    description::AbstractString = "A command.",
    help::AbstractString = "そんなのないよ？",
    onfail::AbstractString = "Command failed."
)

    isPlain = occursin(invocation, invocation.pattern)
    # Make sure that any symbols in the command's invocation aren't interpreted as regex control characters.
    fnTakesTheseArgs = first(methods(fn)).sig.types[2:end]

    # First arg MUST be eventInfo
    if fnTakesTheseArgs[1] <: EventInfo || fnTakesTheseArgs[1] == Any
    else
        throw(ArgumentError("Command functions must take EventInfo as first parameter"))
    end

    # If it's a regex and the second arg is a match, do special stuff
    matchparam = !isPlain && length(fnTakesTheseArgs)>1 && fnTakesTheseArgs[2] <: RegexMatch

    if matchparam
        fnTakesTheseArgs = fnTakesTheseArgs[3:end]
    else
        fnTakesTheseArgs = fnTakesTheseArgs[2:end]
    end

    # determine precedence level

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
    for arg in fnTakesTheseArgs
        # Get the regex for the type and add it to the builder.
        push!(invoregexbuilder, typeregex(arg, "p$p"))
        # p<n> is a capture group in the regex for this argument.
        p += 1
    end

    # Without take extra, it has $ to make sure it ends there.
    invoregex = Regex("^$(join(invoregexbuilder,"\\s+"))$(takeExtra ?  "" : "\$")", "i")

    # function name is a regex to match the first part.
    fnname = Regex("^$(invocation.pattern)", "i")
    # advanced stuff
    subcmd = SubCommand(precedence, invoregex, collect(fnTakesTheseArgs), matchparam, fn)
    # check if exists
    possi = filter(x -> x.functionNameMatch == fnname, client.commands)
    if isempty(possi)
        # add a new command (without the string extras, those come later) and sort! the commands.
        prec = isPlain ? 1 : 2 # this is stupid, but, reduce precedence among Commands and make it the usual system among subcommands
        na = isempty(friendlyname) ? invocation.pattern : friendlyname
        cmd = Command(prec, fnname, [subcmd], na, description, help, onfail)
        push!(client.commands, cmd)
        sort!(client.commands, by = x -> x.precedence)
        @debug "Added command $fnname with subcommand $invoregex"
    else
        cmd = first(possi)
        # check if one exists
        possible_exist = findfirst(c -> c.invocation = invoregex)
        if possible_exist === nothing
            push!(cmd.calls, subcmd)
            # need to sort the subcommands
            sort!(cmd.calls, by = x -> x.precedence)
        else
            # if the command already exists, it's already in the right precedence level:
            # Just replace and notify, no need to re-sort.
            cmd.calls[possible_exist] = subcmd
            @warn "Replacing subcommand $invoregex of command $fnname"
        end

        @debug "Added subcommand $invoregex to command $fnname"
    end
end
