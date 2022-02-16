
module MatrixSynchro

include("Commands.jl")

#Types
export  AccessInfo, EventInfo, User, string, show
#state-modifying api commands
        Sync!, SendMessage!, on!, run
#not-state-modifying api commands
        GetRooms, GetDisplayName,
#static strings and stuff
        Event, MessageType,
#(typed) commands
        command!, addTypeRegex!

end
