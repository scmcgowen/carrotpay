local pkey = settings.get("carrotpay.private_key")
if not switchcraft then
    error("Must run on SwitchCraft 3")
end
sleep(1)
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
local sha256 = require("sha256")
local function makeaddressbyte(byte)
    local byte = 48 + math.floor(byte/7)
    return string.char(byte + 39 > 122 and 101 or byte > 57 and byte + 39 or byte)
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
    local a = http.get("https://krist.dev/addresses/"..addr)
    local balance = textutils.unserializeJSON(a.readAll()).address.balance
    a.close()
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
        request = textutils.serialiseJSON{
            privatekey = pkey,
            to = to,
            amount=amt,
            metadata=mta
        }
        r,err = http.post("https://krist.dev/transactions",request,{["Content-Type"]="application/json"})
        --print(r,err)
        if r then return true else return false end
    end
end
local function handleCommands()
    while true do
        local command = {os.pullEvent("command")}
        if command[3] == "pay" and command[5].ownerOnly then
            if not command[4][1] then
                chatbox.tell(command[2],"Specify who to pay","&6CarrotPay")
            elseif not command[4][2] then
                chatbox.tell(command[2],"Specify how much to pay","&6CarrotPay")
            else
                local c = false
                command_copy = {table.unpack(command)}
                mta = table.concat({select(3, unpack(command_copy[4]))}, " ")
                local s = command[4][1]
                -- require("cc.pretty").pretty_print(s)
                --print(#s)
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
        end
    end
end
handleCommands()
