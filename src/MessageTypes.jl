module MessageType
const text = "m.text"
# m.text
# usually just the 'body' is what we care about
# body::String
# msgtype: m.text
# how edits look:
# body::String
# m.newcontent =>
#       body::String
#       msgtype: m.text
# m.relates_to =>
#       rel_type: m.replace
#       event_id:: (an event ID)
const image = "m.image"
# m.image: Sends an *uploaded image* as a message, eg.
# info=> 
#       h::Int
#       w::Int
#       size::Int (Size of image in bytes)
#       mimetype
#       xyz.amorgan.blurhash    (I assume this generates the blur. TODO: learn what this is if I ever want to send images.)
# url => mxc://matrix.org/[image ID]
end
