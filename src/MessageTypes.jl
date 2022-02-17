module MessageType
const text = "m.text"
const image = "m.image"
# m.image: Sends an *uploaded image* as a message, eg.
# info=> 
#       h::Int
#       w::Int
#       size::Int (Size of image in bytes)
#       xyz.amorgan.blurhash    (I assume this generates the blur. TODO: learn what this is if I ever want to send images.)
# url => mxc://matrix.org/[image ID]
end
