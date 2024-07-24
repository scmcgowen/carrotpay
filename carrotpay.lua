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
prt = require("cc.pretty").pretty_print
local owner,obj =chatbox.getLicenseOwner()
local ownerUUID = obj.uuid

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

local function getName(s)
    if s:match("^[%a%d]+%.kst") then
        name = s:gsub("%.kst","")
        local resp,err = http.get("https://krist.dev/names/"..name)
        local balance
        if resp then
            local response = textutils.unserialiseJSON(resp.readAll())
            resp.close()
            if response.ok then
                return response.name.owner,true
            else
                return nil,false,response.message
            end
        end
    elseif s:match("^[a-zA-Z0-9_]+.crt") then
        local resp,err = http.get("https://carrotpay.herrkatze.com/v2/address?name="..s)
        if resp then 
            local response = resp.readAll()
            if response:match("^k[%a%d]+") and #response == 10 then
                return response,true
            else
                return nil,false,response
            end
        end
    end
end
local function get_balance(addr)
    local ok,err
    if addr:match("^[%a%d]+%.kst") or addr:match("^[a-zA-Z0-9_]+.crt") then
        addr,ok,err = getName(addr)
        if not ok then return -1,false,err end
    end
    local resp,r_err = http.get("https://krist.dev/addresses/"..addr)
    local balance
    if resp then
        local response = textutils.unserialiseJSON(resp.readAll())
        resp.close()
        if response.ok then
        return response.address.balance,true
        else
            return -1,false,response.message
        end
    end
    return -1,false,"An unknown error has occurred, please try again"
end
local function pay(to,amt,mta)
    if not mta then mta = "" end
    -- Integration with ShreksHellraiser's lotto
    if to == "lotto@gambling.kst" then
        if not mta:find("number=") then
            local number = math.random(0,9999)
            local number = string.format("%04d",number)
            mta = "number="..number..";"..mta
        end
        if not mta:find("length=") and not mta:find("donate=true") then 
            mta = "length="..amt..";"..mta
        end
    end
    --End Integration
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
        socket = http.websocket(resp.url)
        print("Connected to Krist Websockets")
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
                        local hasUsername = false
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
                                if p:match("username") and not hasUsername then
                                    from = split(p,"=")[2].." ("..wsevent.transaction.from..")"
                                    hasUsername = true
                                end
                            end
                        end
                        msg2 = "You have received <:kst:665040403224985611>"..wsevent.transaction.value.." from "..from
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
                fs.delete(shell.getRunningProgram())
                shell.run("wget https://raw.githubusercontent.com/scmcgowen/carrotpay/main/carrotpay.lua "..shell.getRunningProgram())
                os.reboot()
            end
            if not command[4][1] then
                chatbox.tell(command[2],"Specify who to pay","&6CarrotPay")
            elseif not command[4][2] then
                chatbox.tell(command[2],"Specify how much to pay","&6CarrotPay")
            else
                local c = false
                local command_copy = {table.unpack(command)}
                local mta = table.concat({select(3, unpack(command_copy[4]))}, " ")
                if not mta then mta = "" end
                mta = "username="..owner..";".."useruuid="..ownerUUID..";"..mta
                local s = command[4][1]
                if (s:match("^k[a-z0-9]+$") and #s == 10) or s:match("^[%a%d_-]+@[%a%d]+%.kst$") or s:match("^[%a%d]+%.kst") then
                    c = pay(s,command[4][2],mta)
                    if c then
                        chatbox.tell(command[2],"Paid <:kst:665040403224985611>"..command[4][2].." to "..s,"&6CarrotPay")
                    end
                elseif s:match("^[a-zA-Z0-9_]+$") and #s <16 then
                    c = pay(s.."@sc.kst",command[4][2],mta)
                    if c then
                        chatbox.tell(command[2],"Paid <:kst:665040403224985611>"..command[4][2] .. " to "..s,"&6CarrotPay")
                    end
                elseif s:match("^[a-zA-Z0-9_]+.crt") or s:match("^[a-zA-Z0-9_]+@[a-zA-Z0-9_]+.crt") then
                    local baseName = s
                    if s:match("@") then
                        baseName = split(s,"@")[2]
                    end
                    local rq,err = http.get("https://carrotpay.herrkatze.com/address?name="..baseName)
                    local addr
                    if rq then
                    addr = rq.readAll()
                    end
                    rq.close()
                    rq = nil
                   
                    if addr and addr ~= "No address with this name could be found" then
                        mta = s..";"..mta
                        c=pay(addr,command[4][2],mta)
                    elseif addr == "No address with this name could be found" then
                        c=true -- Suppress There was an error message
                        chatbox.tell(command[2],"No address found","&6CarrotPay")
                    else
                        print(err)
                    end
                    if c then
                        chatbox.tell(command[2],"Paid <:kst:665040403224985611>"..command[4][2].." to "..s,"&6CarrotPay")
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
        elseif (command[3] == "bal" or command[3] == "balance") and command[5].ownerOnly then
            local addr = command[4][1] or address
            print(addr)
            local bal,ok,err = get_balance(addr)
            if ok then
                chatbox.tell(owner,addr.." has a balance of <:kst:665040403224985611>"..bal,"&6CarrotPay")
            else
                chatbox.tell(owner,tostring(err),"&6CarrotPay")
            end
        elseif (command[3] == "crt" or command[3] == "kst" or command[3] == "name") and command[5].ownerOnly then
            local action = command[4][1]
            local name = command[4][2]
            local addr = command[4][3] -- only applicable to ^crt transfer
            if name then
                local name_owner,ok,err = getName(name) -- check if name exists
                if (action == "purchase" or action == "register") and name then
                    if ok then
                        chatbox.tell(owner,"Name "..name.." already exists and is owned by "..name_owner)
                    elseif name:match("^[%a%d]+%.kst") then
                        local bal,bal_ok,err = get_balance(address)
                        if bal and bal >= 500 then --Make sure you have enough krist to register the name on the kst network
                            http.post("https://krist.dev/names/"..name:gsub("%.kst",""),textutils.serialiseJSON{privatekey=pkey})
                            chatbox.tell(owner,"Successfully registered "..name)
                        elseif bal and bal_ok then
                            chatbox.tell(owner,"Not enough kst to register name.")
                        elseif not bal_ok then
                            chatbox.tell(owner,"Error getting balance: "..err)
                        end
                    elseif name:match("^[a-zA-Z0-9_]+.crt") then
                        local pay_ok = pay("carrotpay.kst",10,"get_name="..name)
                        if pay_ok then 
                            sleep(0.5)
                            local name_owner2,ok2,err = getName(name) -- Check if the name got properly registered
                            if not ok2 then
                                chatbox.tell(owner,"crt Name Server error, please ping @herrkatze0658")
                            end
                        end
                    else
                        chatbox.tell(owner,"Name invalid, please check your input and include .kst or .crt")
                    end
                elseif action == "transfer" and name and addr then
                    if not ok then
                        chatbox.tell(owner,"Error: "..err)
                    elseif name:match("^[%a%d]+%.kst") then
                        if ok and name_owner == address then --Make sure you have enough krist to register the name on the kst network
                            http.post("https://krist.dev/names/"..name:gsub("%.kst","").."/transfer",textutils.serialiseJSON{privatekey=pkey,address=addr})
                            chatbox.tell(owner,"Successfully transferred "..name)
                        elseif name_owner ~= address then
                            chatbox.tell(owner,"Error: You do not own "..name)
                        else
                            chatbox.tell(owner,"An unknown error occurred")
                        end
                    elseif name:match("^[a-zA-Z0-9_]+.crt") then
                        local pay_ok
                        if ok and name_owner == address then
                            pay_ok = pay("carrotpay.kst",1,"name="..name..";transfer_to="..addr)
                        elseif name_owner ~= address then
                            chatbox.tell(owner,"Error: You do not own "..name)
                        else
                            chatbox.tell(owner,"An unknown error occurred")
                        end
                        if pay_ok then 
                            sleep(0.5)
                            local name_owner2,ok2,err = getName(name) -- Check if the name got properly transferred
                            if not ok2 or name_owner2 ~= addr then
                                chatbox.tell(owner,"Possible crt Name Server error, please ping @herrkatze0658 if no refund appears below")
                            end
                        elseif name_owner == address then
                            chatbox.tell(owner,"Failed to transfer name, 1 kst is required to transfer a name due to technical limitations, it will be refunded.")
                        end
                    else
                        chatbox.tell(owner,"Name invalid, please check your input and include .kst or .crt")
                    end
                else
                    chatbox.tell(owner,"Usage: ^name register <name> or ^name transfer <name> <address>")
                end
            else
                chatbox.tell(owner,"Usage: ^name register <name> or ^name transfer <name> <address>")
            end
        end
    end
end
_,e = pcall(parallel.waitForAny,handleWebSockets,handleCommands)
if socket then socket.close() end
printError(e)
