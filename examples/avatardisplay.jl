using MatrixSynchro

client = Client(readlines("token.txt")...)

command!(
    client,
    "avatarurl",
    help = "Needs a user!",
    onfailure = "Are you sure that user exists?"
) do info::EventInfo, user::User
    #dark magic.
    url = getavatar(client, user)
    body = Dict("msgtype"=>"m.image", "body"=>"user.png", "url"=>url)
    MatrixSynchro.matrixrequest(client.info, "PUT", "rooms/$(info.room)/send/m.room.message/$(MatrixSynchro.txnid(client))", body)
end

run(client)