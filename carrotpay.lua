local pkey = settings.get("carrotpay.private_key")
if not switchcraft then
    error("Must run on SwitchCraft 3")
end
sleep(1)
local sha256 = require("sha256")
if not chatbox or not chatbox.hasCapability("command") or not chatbox.hasCapability("tell") then
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.white)
    print("Hey! it seems like you haven't registered chatbox")
    print("If you don't have a chatbox key, run this command:")
    term.setTextColor(colors.green)
    print("/chatbox register")
    term.setTextColor(colors.white)
    print("Then copy that key and paste it here")
    write("Alternatively, run ")
    term.setTextColor(colors.blue)
    print("chatbox register <key>")
    term.setTextColor(colors.white)
    local cbkey = read()
    settings.set("chatbox.license_key",cbkey)
    settings.save(".settings")
    print("Key set. Press Any Key to reboot")
    os.pullEvent("key")
    os.reboot()
end
if not pkey then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.lightGray)
    print("Initial Setup                                      ")
    term.setBackgroundColor(colors.black)
    print("First, CarrotPay needs your private key")
    print("for the wallet you wish to use with CarrotPay")
    print("Please enter your private key (not password) here")
    local ipkey = read()
    settings.set("carrotpay.private_key",ipkey)
    settings.save(".settings")
    term.clear()
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.lightGray)
    print("Initial Setup                                       ")
    term.setBackgroundColor(colors.black)
    print("Do you want to use our default startup script?")
    print("(Y/N)")
    print("Typing anything other than Y will be treated as no")
    term.setTextColor(colors.red)
    print("WARNING! Saying yes will OVERWRITE startup.lua")
    term.setTextColor(colors.white)
    local event = {os.pullEvent("key")}
    if event[2] == keys.y then
        print("Overwrote startup file.")
        fs.delete("startup.lua")
        local file = fs.open("startup.lua","w")
        file.write([=[while true do
        shell.run("]=]..shell.getRunningProgram()..[=[")
        sleep(2)
        end]=])
        file.close()
    end
    print("CarrotPay Setup Requires a reboot.")
    print("Press any key to reboot")
    os.pullEvent("key")
    os.reboot()
end
local owner =chatbox.getLicenseOwner()
local function makeaddressbyte(byte)
    local byte = 48 + math.floor(byte/7)
    return string.char(byte + 39 > 122 and 101 or byte > 57 and byte + 39 or byte)
end
local expect = require("cc.expect").expect
local function split(inputstr, sep)
    expect(1,inputstr,"string")
    expect(1,sep,"string","nil")
    sep = sep or ","
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
  end
  
local function make_address(key)
  local protein = {}
  local stick = sha256(sha256(key))
  local n = 0
  local link = 0
  local v2 = "k"
  repeat
      if n<9 then protein[n] = string.sub(stick,0,2)
      stick = sha256(sha256(stick)) end
      n = n+1
  until n==9
  n=0
  repeat
      link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
      if string.len(protein[link]) ~= 0 then
          v2 = v2 .. makeaddressbyte(tonumber(protein[link],16))
          protein[link] = ''
          n=n+1
      else
      stick = sha256(stick)
      end
  until n==9
  return v2
end
local address = make_address(pkey)
local function get_balance(addr)
    os.queueEvent("get_balance",addr)
    _,balance = os.pullEvent("balance")
    return balance
end
local function pay(to,amt,mta)
    if not mta then mta = "" end
    amt = tonumber(amt)
    local bal = get_balance(address)
    if amt > bal then
        chatbox.tell(owner,"Transaction failed. Not enough Krist","&6CarrotPay")
        return false
    else
        os.queueEvent("make_transaction",to,amt,mta)
        _,ok = os.pullEvent("transaction_complete")
        return ok
    end
end
local function handleWebSockets()
    local id = -1
    local r = http.post("https://krist.dev/ws/start","{\"privatekey\":\""..pkey.."\"}",{["content-type"]="application/json"})
    local resp = textutils.unserialiseJSON(r.readAll())
    r.close()
    r = nil
    if  resp.ok then
        local socket = http.websocket(resp.url)
        id = id + 1
        socket.send('{\"id\":'..id ..',\"type\":\"subscribe\",\"event\":\"ownTransactions\"}')
        while true do
            event = {os.pullEvent()}
            if event[1] == "websocket_message" then
                if event[2] == resp.url then
                    wsevent = textutils.unserialiseJSON(event[3])
                    if wsevent.event == "transaction" and wsevent.transaction.to == address then
                        local from = wsevent.transaction.from
                        local hasMessage = false
                        local hasError = false
                        local message = ""
                        err = ""
                        if wsevent.transaction.metadata then
                            mta = split(wsevent.transaction.metadata,";")
                            for i,p in pairs(mta) do
                                if p:match("message") then
                                    message = split(p,"=")[2]
                                    hasMessage = true
                                end
                                if p:match("error") then
                                    err = split(p,"=")[2]
                                    hasError = true
                                end
                                if p:match("username") then
                                    from = split(p,"=")[2].." ("..wsevent.transaction.from..")"
                                end
                            end
                        end
                        msg2 = "You have received K"..wsevent.transaction.value.." from "..from
                        if hasMessage or hasError then
                            if hasMessage then
                                msg2 = msg2.."\nMessage: "..message
                            end
                            if hasError then
                                msg2 = msg2.."\nError: "..err
                            end
                        end
                        chatbox.tell(owner,msg2,"&6CarrotPay")
                    elseif wsevent.type == "keepalive" or wsevent.type == "response" then
                    else
                    end
                end
            elseif event[1] == "get_balance" then
                id = id + 1
                local rq = {
                    id = id,
                    type="address",
                    address=event[2]
                } 
                socket.send(textutils.serialiseJSON(rq))
                rspt =socket.receive()
                rsp = textutils.unserialiseJSON(rspt)
                os.queueEvent("balance",rsp.address.balance)

            elseif event[1] == "make_transaction" then
                id = id + 1
                local rq = {
                    id = id,
                    type="make_transaction",
                    to = event[2],
                    amount = event[3],
                    metadata = event[4],
                }
                socket.send(textutils.serialiseJSON(rq))
                local c
                repeat
                c = socket.receive()
                c = textutils.unserialiseJSON(c)
                until c.type == "response"
                os.queueEvent("transaction_complete",c.ok)
            end
        end
    end
end
local function handleCommands()
    while true do
        local command = {os.pullEvent("command")}
        if command[3] == "pay" and command[5].ownerOnly then
            if command[4][1] == "--update" then
                shell.run("wget https://raw.githubusercontent.com/scmcgowen/carrotpay/main/carrotpay.lua "..shell.getRunningProgram())
                os.reboot()
            end
            if not command[4][1] then
                chatbox.tell(command[2],"Specify who to pay","&6CarrotPay")
            elseif not command[4][2] then
                chatbox.tell(command[2],"Specify how much to pay","&6CarrotPay")
            else
                local c = false
                command_copy = {table.unpack(command)}
                mta = table.concat({select(3, unpack(command_copy[4]))}, " ")
                local s = command[4][1]
                if ((s:match("^k[a-z0-9]+$") or s:match("^[a-f0-9]+$")) and #s == 10) or (s:match("^[a-z0-9]@[a-z0-9]+$")) or s:match("^[%a%d]+@[%a%d]+%.kst$") or s:match("^[%a%d]+%.kst") then
                    c = pay(s,command[4][2],mta)
                    if c then
                        chatbox.tell(command[2],"Paid <:kst:665040403224985611>"..command[4][2].." to "..s,"&6CarrotPay")
                    end
                elseif s:match("^[a-zA-Z0-9_]+$") and #s <16 then
                    c = pay(s.."@sc.kst",command[4][2],mta)
                    if c then
                        chatbox.tell(command[2],"Paid <:kst:665040403224985611>"..command[4][2] .. " to "..s,"&6CarrotPay")
                    end
                else
                    chatbox.tell(command[2],"Invalid Krist Address","&6CarrotPay")
                end
                if not c then
                    chatbox.tell(command[2],"There was an error.","&6CarrotPay")
                end
            end
        elseif command[3] == "request" and command[5].ownerOnly then
            msg = table.concat({select(3,unpack(command[4]))}, " ")
            if msg == "" then
            chatbox.tell(command[4][1],owner.." wants <:kst:665040403224985611>"..command[4][2].." from you.\nPay to "..address,"&6CarrotPay")
            else
            chatbox.tell(command[4][1],owner.." wants <:kst:665040403224985611>"..command[4][2].." from you.\nPay to "..address.."\nMessage: "..msg,"&6CarrotPay")
            end
            chatbox.tell(owner,"Requested <:kst:665040403224985611>"..command[4][2].." from "..command[4][1],"&6CarrotPay")
        end
    end
end
parallel.waitForAny(handleWebSockets,handleCommands)
