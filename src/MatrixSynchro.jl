module MatrixSynchro

using HTTP
using JSON
using Dates

# these have to be in this order
include("Types.jl")
include("Events.jl")
include("MessageTypes.jl")
include("MatrixClient.jl")
include("TypedCommands.jl")
include("Commands.jl")

# Types
export AccessInfo, EventInfo, User, Client,
# static string data
Event, MessageType,
# Commands on types
string, show,
# state-modifying api commands
sync!, sendmessage!, editmessage!, react!, faketyping!, on!, run,
# not-state-modifying api commands
getrooms, getdisplayname,
# (typed) commands
command!, typeregex, argparse

end
