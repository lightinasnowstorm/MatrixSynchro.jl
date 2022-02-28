import Base: run

# Not sure what version would be best to use.
const matrixBaseURL = "/_matrix/client/r0/"

"""
    matrixrequest(info, func, endpoint, body = Dict())

(internal)
Sends a request to the Matrix homeserver.

`info` - Authentication information for the request.

`fun` - the HTTP function that the request uses.

`endpoint` - the endpoint to request to, after /_matrix/client/r0/

`body` - body for the request, sent as JSON
"""
function matrixrequest(info::AccessInfo, func::String, endpoint::String, body = Dict())
    # Success or failure, just send the result back to the calling function:
    # It gets to deal with what went wrong.
    try
        HTTP.request(func,
            "https://$(info.serverURL)$matrixBaseURL$endpoint",
            Dict("Authorization" => "Bearer $(info.accessToken)",
                "User-Agent" => "MatrixClient.jl"),
            JSON.json(body))
    catch e
        e
    end
end

"""
    txnid(client)

(internal)
Generates a unique transaction ID for the specified client.
"""
function txnid(client::Client)
    "m$(Int(1000*datetime2unix(now()))).$(client.changyThing.reqID+=1)"
end

"""
    sendmessage(client, roomID, message)

Sends a text message in a channel. Does not support formatting
"""
function sendmessage!(client::Client, roomID, msg)
    res = matrixrequest(client.info,
        "PUT",
        "rooms/$roomID/send/m.room.message/$(txnid(client))",
        Dict("body" => msg, "msgtype" => "m.text"))
    res.status == 200 || throw(MatrixError("Unable to send message."))
    # return the event ID of the sent message.
    JSON.parse(String(res.body))["event_id"]
end

"""
    sendformattedmessage(client, roomID, message)

Sends a message with Matrix's custom HTML formatting.
"""
function sendformattedmessage!(client::Client, roomID, msg)
    res = matrixrequest(client.info,
    "PUT",
    "rooms/$roomID/send/m.room.message/$(txnid(client))",
    Dict(
        "body"=>msg,
        "msgtype"=>"m.text",
        "format"=> "org.matrix.custom.html",
        "formatted_body"=>msg
    ))
    JSON.parse(String(res.body))["event_id"]
end

"""
    editmessage!(client, roomID, eventID, newContent)

Changes the content of the message referred to by `eventID` to `new_content`.
`roomID` is the channel that the message to edit is in.
"""
function editmessage!(client::Client, roomID, eventID, newContent)
    res = matrixrequest(client.info, "PUT",
        "rooms/$roomID/send/m.room.message/$(txnid(client))",
        Dict(
            "body" => " * $newContent",
            "msgtype" => "m.text",
            "m.new_content" => Dict(
                "body" => newContent,
                "msgtype" => "m.text" # Can messages change type?
            ),
            "m.relates_to" => Dict(
                "rel_type" => "m.replace",
                "event_id" => eventID
            )))
    res.status == 200 || throw(MatrixError("Unable to edit message."))
    JSON.parse(String(res.body))["event_id"]
end

"""
    reply!(client, info, reply)

Sends a message as a reply to another message, given as as an EventInfo
"""
function reply!(client::Client, info::EventInfo, reply::String)
    #get the "string" to reply to.
    replystring = if info.content["msgtype"] == MessageType.text
        info.content["body"]
    elseif info.content["msgtype"] == MessageType.image
        "sent an image."
    end
    a = Dict(
        "body" => "> <$(info.sender)> $replystring\n\n$reply",
        "format" => "org.matrix.custom.html",
        "msgtype" => "m.text",
        "formatted-body" => "<mx-reply><blockquote><a href=\"https://matrix.to/#/$(info.channel)/$(info.eventID)\">In reply to </a>" *
                            "<a> href=\"https://matrix.to/#/$(info.sender)\">$(info.sender)</a> $replystring</blockquote></mx-reply>$reply",
        "m.relates_to" => Dict(
            "m.in_reply_to" => Dict(
                "event_id" => info.eventID
            )
        )
    )

    matrixrequest(client.info, "PUT", "rooms/$(info.channel)/send/m.room.message/$(txnid(client))", a)
end

"""
    faketyping!(client, roomID, typing)

Sends an ephemeral event to activate the typing indicator for the bot.

isTyping - Whether to activate or deactivate the typing indicator.

duration - If activating the typing indicator, how long it will stay active for.
"""
function faketyping!(client::Client, roomID, isTyping::Bool = true; duration = 30)
    # The timeout only appears when typing is true. Again, it is in ms while the argument in the function is in seconds.
    req = isTyping ? Dict("typing" => true, "timeout" => duration * 1000) : Dict("typing" => false)
    res = matrixrequest(client.info, "PUT", "rooms/$roomID/typing/$(client.info.ID)", req)
    res.status == 200 || throw(MatrixError("unable to fake typing"))
end

"""
    react!(client, roomID, eventID, reaction)

Adds `reaction` to the reactions on the message referred to by `eventID`.
`roomID` is the channel that the message to react to is in.
"""
function react!(client::Client, roomID, eventID, reaction)
    res = matrixrequest(client.info, "PUT",
        "rooms/$roomID/send/m.reaction/$(txnid(client))",
        Dict("m.relates_to" => Dict("event_id" => eventID, "key" => reaction, "rel_type" => "m.annotation")))
    res.status == 200 || throw(MatrixError("unable to add reaction"))
end


"""
    getrooms(info|client)

Gets all rooms that the bot user is in.
"""
function getrooms(info::AccessInfo)
    res = matrixrequest(info, "GET", "joined_rooms")
    res.status ≠ 200 && throw(MatrixError("unable to get rooms"))
    jsonRes = JSON.parse(String(res.body))
    jsonRes["joined_rooms"]
end

function getrooms(client::Client)
    getrooms(client.info)
end

"""
    getdisplayname(info|client, userID)

Gets the current display name for the user specified by `userID`
"""
function getdisplayname(info::AccessInfo, userID)
    res = matrixrequest(info, "GET", "profile/$userID/displayname")
    res.status ≠ 200 && throw(MatrixError("no such user."))
    jsonRes = JSON.parse(String(res.body))
    jsonRes["displayname"]
end

function getdisplayname(client::Client, userID)
    getdisplayname(client.info, userID)
end

"""
    isvalid(event)

Checks if an event has everything it should.
"""
function isvalid(event)
    t=event["type"]
    haskey(event,"content") || return false
    content = event["content"]
    if t==Event.message
        msgt = content["msgtype"]
        if msgt == MessageType.text
            haskey(content, "body")
        elseif msgt == MessageType.image
            haskey(content, "body") && haskey(content, "url")
        elseif msgt == MessageType.video
            haskey(content, "body") && haskey(content, "url")
        else
            false
        end
    elseif t==Event.reaction
        haskey(content, "m.relates_to") &&
            haskey(content["m.relates_to"], "key") &&
            haskey(content["m.relates_to"], "event_id")
    elseif t==Event.member_update
        haskey(content, "avatar_url") && haskey(content, "displayname")
    elseif t==Event.room_name_change
        haskey(content, "name")
    elseif t==Event.room_avatar_change
        haskey(content, "url")
    else
        false
    end
end

"""
    sync!(client, timeout = 30)

Gets events from the homeserver and executes callbacks and commands on the events received.
Takes `timeout` seconds to time out if no events are received.
"""
function sync!(client::Client, timeout::Int = 30)
    # options have to be in URI format
    hasSyncToken = client.changyThing.syncToken ≠ ""
    options = ["filter=0", "full_state=false"]
    # Timeout is 30s with a sync token, 10m without.
    if hasSyncToken
        # the timeout passed to the function is in seconds, but the matrix api wants milliseconds
        push!(options, "timeout=$(timeout*1000)")
        push!(options, "since=$(client.changyThing.syncToken)")
    else
        push!(options, "timeout=600000")
    end

    @debug "sending request"
    res = matrixrequest(client.info, "GET", "sync?$(join(options,"&"))")

    if res.status ≠ 200
        @warn "Sync status was not 200. Exiting."
        return
    end

    jsonRes = JSON.parse(String(res.body))
    # Sync tokens are the next_batch telling when to fetch events from.
    client.changyThing.syncToken = jsonRes["next_batch"]

    # If there is no sync tokens, events could be from the past,
    # so we do not want to act on those events as they are not current.
    # However, make sure the sync token has been gotten from the sync first.
    if !hasSyncToken
        @debug "No sync token. Exiting."
        return
    end

    # This usually happens if the request times out.
    if !haskey(jsonRes, "rooms")
        @debug "No room data in response. Exiting."
        return
    end

    # We are only interested in the events from rooms the bot is in.
    rooms = jsonRes["rooms"]["join"]
    @debug "starting sync for loop"

    for (roomName, roomData) in rooms, event in roomData["timeline"]["events"]
        @debug "In room $roomName on an event"



        @debug event

        # Don't react to the bot's own messages unless running tests.
        if !isvalid(event)
            @warn "Invalid message..."
            continue
        end
        sender = event["sender"]
        if sender ≠ client.info.ID || client.testing
            type = event["type"]
            eventinfo = EventInfo(event["event_id"], type, sender, roomName, event["content"])
            runCallbacks(client, eventinfo)
            if type==Event.message
                runcmds(client, eventinfo)
            end
            
        end
    end
    @debug "end sync for loop"
end

function runCallbacks(client::Client, event::EventInfo)
    # If there are callbacks, run them.
    if haskey(client.callbacks, event.type)
        typecallbacks = client.callbacks[event.type]
        @debug "Executing $(length(typecallbacks)) callback(s) for $(event.type)"
        for callback in typecallbacks
            # Callbacks are user provided code and can error individually:
            # Errors in one callback should not prevent others from running.
            try
                callback(event)
            catch
                @error e
                if client.errors
                    throw(e)
                end
            end
        end
    end
end

"""
    on!(function, client, event)

Adds a callback for `event` to the client.
"""
function on!(fn::Function, client::Client, event::String)
    fnTakesTheseArgs = first(methods(fn)).sig.types[2:end]
    if length(fnTakesTheseArgs) == 1 &&
        (fnTakesTheseArgs[1] <: EventInfo || fnTakesTheseArgs[1] == Any)
    else
        throw(ArgumentError("Callbacks must only take one argument of type EventInfo"))
    end
    if haskey(client.callbacks, event)
        push!(client.callbacks[event], fn)
    else
        client.callbacks[event] = [fn]
    end
end

"""
    run(client, timeout = 30)

Infinitely listens for and reacts to events with the specified client. `timeout` is the timeout to use with `sync!`
"""
function run(client::Client, timeout::Int = 30)
    while true
        sync!(client, timeout)
    end
end
