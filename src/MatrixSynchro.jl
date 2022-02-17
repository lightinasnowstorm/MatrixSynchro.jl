module MatrixSynchro

include("Commands.jl")

# Types
export AccessInfo, EventInfo, User,
# Commands on types
string, show
# state-modifying api commands
sync!, sendmessage!, react!, on!, run
# not-state-modifying api commands
getrooms, getdisplayname,
# static string data
Event, MessageType,
# (typed) commands
command!, typeregex, argparse

end
