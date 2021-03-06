require('common')
local config = require('config')
local ota = require('ota')

local function connect_wifi(cb) 
    wifi.setmode(wifi.STATION)
    local station_cfg = {
        ssid = config.wifi.ssid,
        pwd = config.wifi.pwd,
        save = true
    }
    wifi.sta.config(station_cfg)
    
    wifi.sta.autoconnect(1)
    wifi.sta.connect()

    wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(T)
        wifi.eventmon.unregister(wifi.eventmon.STA_CONNECTED)
        cb('\n\tSTA - CONNECTED'..'\n\tSSID: '..T.SSID..'\n\tBSSID: '..
            T.BSSID..'\n\tChannel: '..T.channel)
    end)

end

local function sync_rtc(cb)
    sntp.sync({ '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org' },
      function(sec, usec, server, info)
        cb('sync', sec, usec, server)
      end,
      function()
       cb('failed!')
      end
    )
end

local function every_second(socket) 
    local unix, _ = rtctime.get()
    local pin = 5
    local status, temp, humi, temp_dec, humi_dec = dht.read(pin)
    if status == dht.OK then
        local data = 'home.temperature ' .. temp .. ' ' .. unix .. '\n' ..
            'home.humidity ' .. humi .. ' ' .. unix .. '\n'
        print('sending:', data)
        socket:send(data)
        print('send ok')
    elseif status == dht.ERROR_CHECKSUM then
        print( "DHT Checksum error." )
    elseif status == dht.ERROR_TIMEOUT then
        print( "DHT timed out." )
    end
end

local function check_update()
    ota.update()
end

local function main()
    coroutine.wrap(function()
        local wifi_info = await(connect_wifi)()
        print('wifi info: ', wifi_info)
        local status, sec, usec, server = await(sync_rtc)()
        print(status, sec, usec, server)
        
        local socket = net.createConnection(net.TCP, 0)
        socket:connect(2003, '10.0.0.220')

        local every_second_timer = tmr.create()
        every_second_timer:register(1000, tmr.ALARM_AUTO, bind(every_second, socket))
        every_second_timer:start()

        local ota_timer = tmr.create()
        ota_timer:register(60000, tmr.ALARM_AUTO, check_update)
        ota_timer:start()
    end)()
end

main()
