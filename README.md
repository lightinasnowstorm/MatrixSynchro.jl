# MatrixSynchro.jl
Matrix bot client for Julia

This is a work in progress.

To use this, you first need to create a client:
```julia
client = Client("<bot account name>", "matrix.org", "<token here>")
```
You can then subscribe to events and create commands:
```julia
on!(client, Event.message) do data::EventInfo
  # Do stuff on the event here
end

command!(client, "beep") do data::EventInfo
  SendMessage!(client, data.channel, "boop!")
end

command!(client, "say") do data::EventInfo, saythis::String
  SendMessage(client, data.channel, "$(GetName(data.sender)) says: $saythis")
end
```

*You may need to put MatrixSynchro. before everything from this package to get it to work.
