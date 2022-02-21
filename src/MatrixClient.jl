# Not sure what version would be best to use.
const matrixBaseURL = "/_matrix/client/r0/"

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

function txnid(client::Client)
    "m$(Int(1000*datetime2unix(now()))).$(client.changyThing.reqID+=1)"
end

function sendmessage!(client::Client, roomID, msg)
    res = matrixrequest(client.info,
        "PUT",
        "rooms/$roomID/send/m.room.message/$(txnid(client))",
        Dict("body" => msg, "msgtype" => "m.text"))
    res.status == 200 || throw(MatrixError("Unable to send message."))
    # return the event ID of the sent message.
    JSON.parse(String(res.body))["event_id"]
end

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

function react!(client::Client, roomID, eventID, reaction)
    res = matrixrequest(client.info, "PUT",
        "rooms/$roomID/send/m.reaction/$(txnid(client))",
        Dict("m.relates_to" => Dict("event_id" => eventID, "key" => reaction, "rel_type" => "m.annotation")))
    res.status == 200 || throw(MatrixError("unable to add reaction"))
end

function getrooms(info::AccessInfo)
    res = matrixrequest(info, "GET", "joined_rooms")
    res.status ≠ 200 && throw(MatrixError("unable to get rooms"))
    jsonRes = JSON.parse(String(res.body))
    jsonRes["joined_rooms"]
end

function getrooms(client::Client)
    getrooms(client.info)
end

function getdisplayname(info::AccessInfo, userID)
    res = matrixrequest(info, "GET", "profile/$userID/displayname")
    res.status ≠ 200 && throw(MatrixError("no such user."))
    jsonRes = JSON.parse(String(res.body))
    jsonRes["displayname"]
end

function getdisplayname(client::Client, userID)
    getdisplayname(client.info, userID)
end

function sync!(client::Client)
    # options have to be in URI format
    hasSyncToken = client.changyThing.syncToken ≠ ""
    options = ["filter=0", "full_state=false"]
    # Timeout is 30s with a sync token, 10m without.
    if hasSyncToken
        push!(options, "timeout=30000")
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

        sender = event["sender"]
        type = event["type"]

        @debug event

        # Don't react to the bot's own messages unless running tests.
        if sender ≠ client.info.ID || client.testing
            # Check if there is a callback for the event type.
            if (haskey(client.callbacks, type))
                # TODO: refactor this out to a validation method for each type of event.
                if type == Event.message && !haskey(event["content"], "body")
                    @warn "Invalid message..."
                    continue
                end

                typecallbacks = client.callbacks[type]
                @debug "Executing $(length(typecallbacks)) callback(s) for $type"
                eventinfo = EventInfo(client, event["event_id"], type, sender, roomName, event["content"])
                for callback in typecallbacks
                    #Callbacks may error (user code), so wrap in try+catch
                    try
                        callback(eventinfo)
                    catch e
                        @error e
                        if client.errors
                            throw(e)
                        end
                    end
                end
            end
            # TODO: more tighly integrate commands in here instead of having them rely on callbacks.
        end
    end
    @debug "end sync for loop"
end

function on!(fn::Function, client::Client, event::String)
    # TODO: validate the function?
    if haskey(client.callbacks, event)
        push!(client.callbacks[event], fn)
    else
        client.callbacks[event] = [fn]
    end
end

function run(client::Client, timeout::Int = 0)
    while true
        sync!(client)
        sleep(timeout)
    end
end
