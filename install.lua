term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
print("Installing CarrotPay")
shell.run("wget https://raw.githubusercontent.com/scmcgowen/carrotpay/main/carrotpay.lua")
shell.run("https://raw.githubusercontent.com/scmcgowen/carrotpay/main/sha256.lua")
shell.run("carrotpay")
