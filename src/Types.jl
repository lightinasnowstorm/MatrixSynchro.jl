import Base: string, show, showerror

"""
    User(id)

Represents a matrix user, holding their ID in the form @username:homeserver
"""
struct User
    ID::String
end

"""
    SubCommand(
        precedence,
        invocation,
        argtypes,
        function
    )

Represents a specific invocation for a `Command`
"""
struct SubCommand
    precedence::Int
    invocation::Regex
    argtypes::Vector{Type}
    fn::Function
end

"""
    Command(
        precedence,
        function name,
        calls,

        friendlyname,
        description,
        help
    )

A command.
"""
struct Command
    precedence::Int
    functionNameMatch::Regex
    calls::Array{SubCommand}

    friendlyname::String
    description::String
    help::String
end

"""
    ConnectionChangyThing(reqID, syncToken, filterID)

These are the mutable aspects of the connection.

`reqID` is the request ID used in creating `txnid`

`syncToken` is passed to the server to receive no events from
before the time the syncToken represents

`filterID` is the ID of the Matrix filter that filters the events the bot receives.
"""
mutable struct ConnectionChangyThing
    reqID::Int
    syncToken::String
    filterID::Int
end

"""
    AccessInfo(ID, serverURL, accessToken)

This is the authentication information for a bot user.

`ID` is the ID of the user in the form @botuser:homeserver

`serverURL` is the URL of the homeserver, without the protocol

`accessToken` is the authentication token for the bot user.
"""
struct AccessInfo
    ID::User
    serverURL::String
    accessToken::String
end

"""
    Client(
        accessinfo,
        changyThing,
        callbacks=Dict(),
        commands=[],
        errors=false,
        testing=false
        )

Simpler constructor:

    Client(
        username,
        homeserver,
        token
        )

A connection to Matrix using the homeserver in `accessinfo`, with callbacks for events and commands: A bot.

`accessinfo` is the authentication information for the bot.

`changyThing` is the mutable aspects of the connection.

`callbacks` is the functions that are called on events.

`commands` is commands, along with their invocations.

`commandPrecedence` controls which commands are called in the event of a conflict
between more and less general commnands. Less general commands are prefered.

`errors` is whether errors that occur in callbacks and commands are passed up.

`testing` is whether this client is used for testing the bot framework.
When true, the bot will execute callbacks and commands on its own messages.
"""
struct Client
    info::AccessInfo
    changyThing::ConnectionChangyThing
    callbacks::Dict{String,Array{Function}}
    commands::Array{Command}
    #commands::Dict{Regex,Function}
    #commandPrecedence::Array{Tuple{Int,Regex}}
    errors::Bool
    testing::Bool
end

"""
    EventInfo(client, eventid, type, sender, room, content)

Information about a triggered event.

`eventID` - The Matrix event ID for this event.

`type` - Type of the event. See `Event` for the different types of events.

`sender` - The Matrix ID of the user who brought about the event.

`room` - The room the event comes from.

`content` - The content of the event. Varies based on event type.
See `Event` and each of the event types within.
"""
struct EventInfo
    eventID::String
    type::String
    sender::String
    room::String
    content::Dict{String,Any}
end

"""
    MatrixError(explanation)

An error that occured with a request to the Matrix homeserver.
"""
struct MatrixError <: Exception
    text::String
end

function showerror(io::IO, e::MatrixError)
    print(io, e.text)
end

"""
    stripprotocol(url)

Removes the protocol from a url.
"""
function stripprotocol(serverURL)
    #No protocol:// in url
    modURL = serverURL
    if occursin("://", serverURL)
        modURL = modURL[findfirst("://", modURL)[3]+1:end]
    end
    modURL
end

User(id::SubString) = User(string(id))

function string(u::User)
    u.ID
end

function show(io::IO, u::User)
    print(io, string(u))
end

AccessInfo(username::String, serverURL::String, accessToken::String) = AccessInfo(User("@$username:$serverURL"), stripprotocol(serverURL), accessToken)

Client(info::AccessInfo, errors::Bool = false, testing::Bool = false) = Client(info, ConnectionChangyThing(0, "", 0), Dict(), [], errors, testing)

Client(username::String, serverURL::String, accessToken::String, errors::Bool = false, testing::Bool = false) = Client(AccessInfo(username, serverURL, accessToken), errors, testing)
