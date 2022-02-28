"""
This is a collection of the types of events that can be emitted.
Currently only `message` and `reaction` have `EventInfo.content` documented.
Events are split into timeline, state, account_data, and ephemeral events. Only timeline events are listened for.
"""
module Event
"""
A message in a channel.
See `MessageType` for more information about this event
and what `EventInfo.content` is for it.
"""
const message = "m.room.message"

"""
A reaction to a message.

Format of `EventInfo.content`:

    content =>
        m.relates_to =>
            rel_type = "m.annotation"
            key::String (The emoji reacted with)
            event_id (The event ID of the message reacted to)
"""
const reaction = "m.reaction"

"""
A change in a member's avatar and/or display name.

Format of `EventInfo.content`:
    
    content =>
        membership = "join"
        avatar_url::String (A matrix URL of the form mxc://homeserver/image_id)
        displayname::String
"""
const member_update = "m.room.member"

"""
A change in the name of the room.

Format of `EventInfo.content`:

    content =>
        name::String (The new name of the room)
"""
const room_name_change = "m.room.name"

"""
A change in the room's avatar.

Format of `EventInfo.content`:

    content =>
        url::String (The matrix URL of the new room avatar)
"""
const room_avatar_change = "m.room.avatar"

"""
Transient events. These are seperate from normal (timeline) events, and are not listened for.
"""
module Ephemeral
"""
Ephemeral event triggered when a user starts or stops typing.

Structure:

    ephemeral =>
        events::Array =>
            type = "m.typing"
                content =>
                    user_ids::Array =>
                        (the IDs of the users that are typing)
"""
const typing = "m.typing"
end

"""
I have no idea what these events are.
"""
module Unknown
const canonical_alias = "m.room.canonical_alias"
const aliases = "m.room.aliases"
const rules = "m.room.join_rules"
end
end
