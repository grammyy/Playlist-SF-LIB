--@name Playlist lib
--@author Elias

function queue(time,func)
    if !waitlist[time] then
        waitlist[time]={}
        local list=waitlist[time]
            
        func()
            
        timer.create("waitlist_"..time,time,0,function()
            if list[#waitlist[time]] then
                list[#waitlist[time]]()
                waitlist[time][#waitlist[time]]=nil
            else
                timer.remove("waitlist_"..time)
                waitlist[time]=nil
            end
        end)
    else
        table.insert(waitlist[time],1,func)
    end
end

if SERVER then
    waitlist={}
    
    net.receive("sv_sync",function(_,ply)
        local packet=net.readTable()
        packet[1].sender=ply:getName()

        net.start("cl_sync")
        net.writeTable(packet[1])
        net.send(packet[2] or nil)
    end)
    
    hook.add("ClientInitialized","cl_request",function(ply)
        if ply:getTimeConnected()>120 then
            return
        end
        
        queue(1/2,function()
            net.start("cl_request")
            net.writeEntity(ply)
            net.send(owner(),false)
        end)
    end)
else
    data={}

    function netSend(message,users)
        net.start("sv_sync")
        net.writeTable(table.add({message},{users}))
        net.send()
    end
    
    net.receive("cl_sync",function()
        for key,packet in pairs(net.readTable()) do
            data[key]=packet

            if key=="songs" then
                printConsole(Color(0,255,0),"[Initialized]",Color(255,255,255),": Loaded "..#packet.." songs.")
            end
            
            if key=="song" then
                bass.loadURL(packet.url,"3d noblock",function(snd,_,err)
                    if data.snd then
                        data.snd:stop()
                        
                        hook.remove("think","cl_snd")
                    end
                    
                    if snd then
                        data.snd=snd
                        data.length=data.snd:getLength()
                        
                        data.snd:play()

                        hook.add("think","cl_snd",function()
                            data.time=data.snd:getTime()
                            
                            snd:setPos(chip():getPos())
                            
                            if sndFFT then
                                sndFFT(snd:getFFT(1))
                            end
                        end)
                        
                        timer.simple(data.length,function()
                            hook.remove("think","cl_snd")
                        end)
                    else
                        print(Color(255,0,0),"[Failed]",Color(255,255,255),": "..err)
                    end
                end)
            end
            
            if key=="time" and data.snd then
                data.snd:setTime(packet)
            end
        end
    end)
    
    if player()==owner() then
        data.songs=bit.stringToTable(file.read("playlist.txt"))
        
        net.receive("cl_request",function()
            local ply=net.readEntity()
            
            netSend(table.add({
                songs=data.songs,
                song=data.song
            },{enviorment or {}}),{ply})
        end)

        netSend(data)
    end
end