# make an EventInfo,
# allowing the bot itself to trigger events and commands, and to error if there is a failure.
client = Client(readlines("testtoken.txt")..., true, true)
#Need to insert a channel name in here for the tests to work.
channel = readlines("testchannel.txt")[1]


on!(client, Event.message) do info::EventInfo
    @test "should not run on first sync" == ""
end

sync!(client)

#clear it.
client.callbacks[Event.message] = []

global textHasRun = false
global reactHasRun = false

on!(client, Event.message) do info::EventInfo
    @test strip(info.content["body"]) == "Hello World!"
    global textHasRun = true
end

on!(client, Event.reaction) do info::EventInfo  
    @test info.content["m.relates_to"]["key"]=="😄"
    global reactHasRun = true
end

# Send messages so the test can proceed.
m = sendmessage!(client, channel, "Hello World!")
react!(client, channel, m, "😄")
#Now that we've sent a message and reacted to it, both should run.
sync!(client)
@test textHasRun
@test reactHasRun

#then remove them for the next test.
client.callbacks[Event.message] = []
client.callbacks[Event.reaction] = []

global textFromEdit

on!(client, Event.message) do info::EventInfo
    @test info.content["m.new_content"]["body"] == "こんにちは世界！"
    @test info.content["m.relates_to"]["rel_type"] == "m.replace"
    global textFromEdit = true
end

# Then check that we can edit the message.
editmessage!(client, channel, m, "こんにちは世界！")
sync!(client)
@test textFromEdit

#then remove it for the remainder.
client.callbacks[Event.message] = []


#then check that commands work

global test1 = false
global testmore = false
global testdigits = false
global testargs = false

command!(client, "test1") do q::EventInfo
    global test1 = true
end

command!(client, "test more", takeExtra = true) do info::EventInfo
    global testmore = true
end

command!(client, r"test\d+") do info::EventInfo
    global testdigits = true
end

command!(client, "alltheargs") do info::EventInfo, a::Int, b::Float64, c::String, d::String, e::User, f::String, g::Bool
    #check all of the args exist and are the expected values.
    args = [a, b, c, d, e, f, g]
    @test args == [45, 45.4, "first half", "of the test", client.info.ID, "no quotes? No problem.", false]
    @test typeof.(args) == [Int, Float64, String, String, User, String, Bool]
    global testargs = true
end

#call the comamnds to check
sendmessage!(client, channel, "test1")
sendmessage!(client, channel, "test more with more")
sendmessage!(client, channel, "test999")
sendmessage!(client, channel, "alltheargs 45 45.4 \"first half\" \"of the test\" $(client.info.ID) no quotes? No problem. false")

#and then sync to run the commands.
sync!(client)

#and they should have all run.
@test test1
@test testmore
@test testdigits
@test testargs
