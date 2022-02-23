"""
The different types of `Event.message` that the bot can receive:
text and image
"""
module MessageType

"""
A text message in a channel.
This can either be a new message sent, or an edit to an existing message.

Format of `EventInfo.content`:

New Message:

    content =>
        msgtype = "m.text"
        body::String

Edited Message:

    content =>
        msgtype = "m.text"
        body::String
        m.newcontent =>
            msgtype = "m.text"
            body::String
        m.relates_to =>
            rel_type = "m.replace"
            event_id (Matrix Event ID)
"""
const text = "m.text"

"""
A message with an image in a channel. This is only an image, no text.

Format of `EventInfo.content`:

    content =>
        msgtype = "m.image"
        url::String = max://matrix.org/[image ID]
        info =>
            h::Int (Height)
            w::Int (Width)
            size::Int (Size of image in bytes)
            mimetype::String
            xyz.amorgan.blurhash::String (This is a blurhash that generates the blur)
"""
const image = "m.image"

end
