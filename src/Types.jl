import Base: string, show, showerror

struct User
    ID::String
end

mutable struct ConnectionChangyThing
    reqID::Int
    syncToken::String
    filterID::Int
end

struct AccessInfo
    ID::User
    serverURL::String
    accessToken::String
end

struct Client
    info::AccessInfo
    changyThing::ConnectionChangyThing
    callbacks::Dict{String,Array{Function}}
    commands::Dict{Regex,Function}
    commandPrecedence::Array{Tuple{Int,Regex}}
    errors::Bool
    testing::Bool
end

struct EventInfo
    client::Client
    EventID::String
    type::String
    sender::String
    channel::String
    content::Dict{String,Any}
end

struct MatrixError <: Exception
    text::String
end

function showerror(io::IO, e::MatrixError)
    print(io, e.text)
end

function StripServerName(serverURL)
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

AccessInfo(username::String, serverURL::String, accessToken::String) = AccessInfo(User("@$username:$serverURL"), StripServerName(serverURL), accessToken)

Client(info::AccessInfo, errors::Bool = false, testing::Bool = false) = Client(info, ConnectionChangyThing(0, "", 0), Dict(), Dict(), [], errors, testing)

Client(username::String, serverURL::String, accessToken::String, errors::Bool = false, testing::Bool = false) = Client(AccessInfo(username, serverURL, accessToken), errors, testing)
