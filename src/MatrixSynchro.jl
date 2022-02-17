
module MatrixSynchro

include("Commands.jl")

#Types
export AccessInfo, EventInfo, User, string, show
#state-modifying api commands
Sync!, SendMessage!, React!, on!, run
#not-state-modifying api commands
GetRooms, GetDisplayName,
#static strings and stuff
Event, MessageType,
#(typed) commands
command!, TypeRegex, ArgParse

end
