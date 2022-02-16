module Event
    # from https://github.com/turt2live/matrix-voyager-bot/blob/master/src/matrix/MatrixClientLite.js line 203
    const message="m.room.message"
    const reaction="m.reaction"
    const member_update="m.room.member"
    const name_change="m.room.name"
    const avatar_change="m.room.avatar"
    const typing="m.typing"
    # Unsure what these events are.
    const canonical_alias="m.room.canonical_alias"
    const aliases="m.room.aliases"
    const rules="m.room.join_rules"
end
