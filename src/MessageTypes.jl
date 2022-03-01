"""
The different types of `Event.message` that the bot can receive:
text, emote, image, and video
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
        m.newcontent => (newcontent is identical to what is under content directly)
            msgtyp e= "m.text"
            body::String
        m.relates_to =>
            rel_type = "m.replace"
            event_id (Matrix Event ID)
"""
const text = "m.text"


"""
A /me message.

Format of `EventInfo.content`: (It's the same as `text`)

New Message:

    content =>
        msgtype = "m.emote"
        body::String

Edited Message:

    content =>(newcontent is identical to what is under content directly)
        msgtype = "m.emote"
        body::String
        m.newcontent =>
            msgtype::String
            body::String
        m.relates_to =>
            rel_type = "m.replace"
            event_id (Matrix Event ID)

"""
const emote = "m.emote"

"""
A message with an image in a channel. This is only an image, no text.

Format of `EventInfo.content`:

    content =>
        msgtype = "m.image"
        body::String (The filename of the image)
        url::String = mxc://homeserver/[image ID]
        info =>
            h::Int (Height)
            w::Int (Width)
            size::Int (Size of image in bytes)
            mimetype::String
            xyz.amorgan.blurhash::String (This is a blurhash that generates the blur)
"""
const image = "m.image"

"""
A message with a video in a channel. There is no text in the message.

Format of `EventInfo.content`:

    content =>
        msgtype = "m.video"
        body::String (Filename of the video)
        url::String = mxc://homeserver/[video ID]
        info =>
            h::Int (Height)
            w::Int (Width)
            size::Int (Size of video in bytes)
            mimetype::String
            xyz.amorgan.blurhash::String (This is a blurhash that generates the blur)
            thumbnail_url::String = mxc://homeserver/[image ID]
            thumbnail_info =>
                h::Int (Height)
                w::Int (Width)
                size::Int (Size of image in bytes)
                mimetype::String
"""
const video = "m.video"
end
