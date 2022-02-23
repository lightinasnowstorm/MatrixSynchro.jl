"""
This is a collection of the types of events that can be emitted.
Currently only `message` and `reaction` have `EventInfo.content` documented.
"""
module Event
# from https://github.com/turt2live/matrix-voyager-bot/blob/master/src/matrix/MatrixClientLite.js line 203
"""
A message in a channel.
See `MessageType`(@ref) for more information about this event
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
const member_update = "m.room.member"
const name_change = "m.room.name"
const avatar_change = "m.room.avatar"
const typing = "m.typing"
# Unsure what these events are.
const canonical_alias = "m.room.canonical_alias"
const aliases = "m.room.aliases"
const rules = "m.room.join_rules"
end
