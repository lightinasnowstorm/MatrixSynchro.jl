
# make an EventInfo,
# allowing the bot itself to trigger events and commands.
client = MatrixSynchro.Client(readlines("testtoken.txt")...,true)
#Need to insert a channel name in here for the tests to work.
channel = readlines("testchannel.txt")[1]

# register that getting stuff actually gets stuff
# GetRooms, GetDisplayName

global onTextShouldRun = false
global textHasRun = false

MatrixSynchro.on!(client, MatrixSynchro.Event.message) do data::EventInfo
    if onTextShouldRun
        global textHasRun = true
    else
        @test "Should not run on first sync"==""
    end
end

#Even if there are messages received, the handler should not run.
MatrixSynchro.Sync!(client)
global onTextShouldRun=true
MatrixSynchro.SendMessage!(client, channel, "Hello World!")
#Now that we've sent a message, it should run.
MatrixSynchro.Sync!(client)
@test textHasRun


#then check that commands work

global test1 = false
global testmore = false
global testdigits = false
global testargs = false

MatrixSynchro.command!(client, "test1") do q::EventInfo
    global test1 = true
end

MatrixSynchro.command!(client, "test more", takeExtra = true) do data::EventInfo
    global testmore = true
end

MatrixSynchro.command!(client, r"test\d+") do data::EventInfo
    global testdigits = true
end

MatrixSynchro.command!(client, "alltheargs") do data::EventInfo, a::Int, b::Float64, c::String, d::String, e::MatrixSynchro.User, f::String, g::Bool
    #check all of the args exist and are the expected values.
    args = [a, b, c, d, e, f, g]
    @test args == [45, 45.4, "first half", "of the test", client.info.ID, "no quotes? No problem.", false]
    @test typeof.(args) == [Int, Float64, String, String, MatrixSynchro.User, String, Bool]
    global testargs = true
end

#call the comamnds to check
MatrixSynchro.SendMessage!(client, channel, "test1")
MatrixSynchro.SendMessage!(client, channel, "test more with more")
MatrixSynchro.SendMessage!(client, channel, "test999")
MatrixSynchro.SendMessage!(client, channel, "alltheargs 45 45.4 \"first half\" \"of the test\" $(client.info.ID) no quotes? No problem. false")

#and then sync to run the commands.
MatrixSynchro.Sync!(client)

#and they should have all run.
@test test1
@test testmore
@test testdigits
@test testargs
