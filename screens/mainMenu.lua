-- screens.mainMenu

local composer = require ("composer")       -- Include the Composer library. Please refer to -> http://docs.coronalabs.com/api/library/composer/index.html
local scene = composer.newScene()           -- Created a new scene

local widget = require ("widget")			-- Included the Widget library for buttons, tabs, sliders and many more
local zip = require( "plugin.zip" )
local MultipartFormData = require("utils.multipartForm")
local lfs = require( "lfs" )
local bestHelper = require "utils.general"
local androidCameraView = require "plugin.androidCameraView"
local socket = require "socket"

local accelerometerText
local gyroText
local gpsText
local compassText
local infoText

local highestValueText
local highestValue = 0

local avgAccelRecords
local avgGyroRecords
local avgGPSRecords
local avgCompassRecords

local trueAccelRecords
local trueGyroRecords
local trueGPSRecords
local trueCompassRecords

local t1

local isActivated = false
local isCalibrated = false
-- first one is start position, last one is end position
local baseTime
local latTable
local longTable
local timeTable

local gridTable
local dangerTable

local bumpThreshold = 3
local fileToDelete, typeToDelete
local csvToDelete, csvType

local isZipping = false
local isUploading = false
local gpsCount
local gpsTotal

local debugCounter = 1
local myTimers = {}

local myView

local Type1 = "accel"
local Type2 = "gyro"
local Type3 = "gps"
local Type4 = "magnetometer"
local Type5 = "bump"

local typeDirectories = {Type1, Type2, Type3, Type4, Type5}

local function cancelAllTimers()
    for k, v in pairs(myTimers) do
        timer.cancel(v)
    end
end

local function networkListener( event )
	print("Init Network Listener")
    if ( event.isError ) then
            print( "Network error!")
			isUploading = false
    else
            --print ( "RESPONSE: " .. event.response )
			print("Success")
			--debugCounter = debugCounter + 1
			--highestValueText.text = "Debug Counter " .. debugCounter
			local destDir = system.DocumentsDirectory  -- Location where the file is stored
			local result, reason = os.remove( system.pathForFile( typeToDelete.."/"..fileToDelete, destDir ) )
			if result then
				print( "ZIP File removed" )
				isUploading = false
			else
				print( "File does not exist", reason )  --> File does not exist    apple.txt: No such file or directory
				isUploading = false
			end
    end
end

local function zipListener( event )
	print("trying to zip" .. csvType)
    if ( event.isError ) then
		isZipping = false
        print( "Error!" )
    else
		local destDir = system.DocumentsDirectory  -- Location where the file is stored
		local result, reason = os.remove( system.pathForFile( csvType.."/"..csvToDelete, destDir ) )
		--local result, reason = os.remove( system.pathForFile( sensorType.."/"..csvToDelete, destDir ) )
		if result then
   			print( "CSV File removed." )
			isZipping = false
		else
   			print( "File does not exist", reason )  --> File does not exist    apple.txt: No such file or directory
			isZipping = false
		end
    end
end

local function writeData(fileName, tableData, sensorType)
	-- Path for the file to write

	--local docs_path = system.pathForFile( "", system.DocumentsDirectory )
	--local success = lfs.chdir( docs_path ) -- returns true on success
	--local new_folder_path
	local path = system.pathForFile( sensorType.."/"..fileName, system.DocumentsDirectory )

	-- Open the file handle
	local file, errorString = io.open( path, "a" )

	if not file then
		-- Error occurred; output the cause
		print( "File error:: " .. errorString )
	else

		for i =1, #tableData do
			file:write(tableData[i], "\,")
		end

		file:write("\n")
		io.close( file )
	end

	file = nil
end

local function updateCompass( event )

	local date = os.date( '*t' )
	local timeNow = os.time( date )

	trueCompassRecords = trueCompassRecords + 1
	--compassText.text = "Geographic: " .. event.geographic .. " Magnetic: " .. math.round(event.magnetic) .. " Rows:" .. trueCompassRecords

	local exampleData = {}
	exampleData[#exampleData+1] = timeNow
	exampleData[#exampleData+1] = event.geographic
	exampleData[#exampleData+1] = event.magnetic


	local secondsPassed = date.sec
	local minutePassed = date.min

	--date.min = date.min - minutePassed
	date.sec = date.sec - secondsPassed

	local editTime = os.time(date)
	local formattedText = editTime..".csv"
	--highestValueText.text = formattedText
	writeData(formattedText,exampleData, Type4)

end

local function locationHandler( event )
	-- Check for error (user may have turned off location services)
	local elpasedSeconds = os.difftime( os.time(), t1 )

	if elpasedSeconds < 3 then
		return
	end

	if ( event.errorCode ) then
			native.showAlert( "GPS Location Error", event.errorMessage, {"OK"} )
			print( "Location error: " .. tostring( event.errorMessage ) )
	else
			local date = os.date( '*t' )
			local timeNow = os.time( date )

			trueGPSRecords = trueGPSRecords + 1
            local speedKM = (event.speed/0.447)*1.609344
			gpsText.text = string.format( '%.4f, %.4f %.2f km/h', event.latitude, event.longitude, event.speed )
			--gpsText.text = "Rows: " .. trueGPSRecords
            gpsCount = gpsCount + 1
            gpsTotal = gpsTotal + event.speed

			latTable[#latTable+1] = event.latitude
			longTable[#longTable+1] = event.longitude
			timeTable[#timeTable+1] = os.time()
			-- event.altitude event.accuracy event.speed event.direction event.time

			local exampleData = {}
			exampleData[#exampleData+1] = timeNow
			exampleData[#exampleData+1] = event.latitude
			exampleData[#exampleData+1] = event.longitude
			exampleData[#exampleData+1] = event.altitude
			exampleData[#exampleData+1] = event.speed
			exampleData[#exampleData+1] = event.direction
			local secondsPassed = date.sec
			local minutePassed = date.min

			--date.min = date.min - minutePassed
			date.sec = date.sec - secondsPassed

			local editTime = os.time(date)
			local formattedText = editTime..".csv"
			--highestValueText.text = formattedText
			writeData(formattedText,exampleData, Type3)
	end
end

-- Called when a new gyroscope measurement has been received
local function onGyroscopeDataReceived( event )
    -- Calculate approximate rotation traveled via delta time
		-- The rotation rate around the device's x-axis in radians per second.
		local date = os.date( '*t' )
		local timeNow = os.time( date )

    	local deltaXRadians = event.xRotation
		local deltaYRadians = event.yRotation
		local deltaZRadians = event.zRotation

		local superTime = event.deltaTime

    	local deltaDegreesX = deltaXRadians * superTime * (180/math.pi) -- convert radians to degrees
		local deltaDegreesY = deltaYRadians * superTime * (180/math.pi)
		local deltaDegreesZ = deltaZRadians * superTime * (180/math.pi)
		trueGyroRecords = trueGyroRecords + 1
		--gyroText.text = string.format( 'X: %.2f, Y: %.2f, Z: %.2f ', deltaDegreesX, deltaDegreesY, deltaZRadians ) .. " Rows: " .. trueGyroRecords


		local exampleData = {}
		exampleData[#exampleData+1] = timeNow
		exampleData[#exampleData+1] = deltaDegreesX
		exampleData[#exampleData+1] = deltaDegreesY
		exampleData[#exampleData+1] = deltaDegreesZ

		local secondsPassed = date.sec
		local minutePassed = date.min

		--date.min = date.min - minutePassed
		date.sec = date.sec - secondsPassed

		local editTime = os.time(date)
		local formattedText = editTime..".csv"
		--highestValueText.text = formattedText
		writeData(formattedText,exampleData, Type2)
end

local function onAccelerate( event )
		local accelXG = event.xGravity  --event.xInstant, xGravity, xRaw
		local accelYG = -event.yGravity
		local accelZG = -event.zGravity

        local accelXI = event.xInstant  --event.xInstant, xGravity, xRaw
        local accelYI = -event.yInstant
        local accelZI = -event.zInstant

        local accelXR = event.xRaw  --event.xInstant, xGravity, xRaw
        local accelYR = -event.yRaw
        local accelZR = -event.zRaw

		local date = os.date( '*t' )
		local timeNow = os.time( date )
        local timeInMS = math.round(socket.gettime() * 1000)


        print("Milliseconds: " .. timeInMS)

		--Provides the acceleration due to gravity relative to the x-axis of the device's screen in portrait orientation.
		trueAccelRecords = trueAccelRecords + 1
		--accelerometerText.text = string.format( '%.2f, %.2f, %.2f ', absolX, absolY, absolZ ) .. " Rows:" .. trueAccelRecords
		accelerometerText.text = string.format( '%.2f, %.2f, %.2f ', accelXG, accelYG, accelZG )

		local exampleData = {timeInMS, accelXG, accelYG, accelZG, accelXI, accelYI, accelZI, accelXR, accelYR, accelZR}

		local secondsPassed = date.sec
		local minutePassed = date.min

		--date.min = date.min - minutePassed
		date.sec = date.sec - secondsPassed

		local editTime = os.time(date)
		local formattedText = editTime..".csv"
		--highestValueText.text = formattedText
		writeData(formattedText,exampleData, Type1)

end



-- https://docs.coronalabs.com/guide/data/LFS/index.html#directory-scanning
local function zipFunc(sensorType)

	if (isZipping) then
		return
	end
	-- Currently not doing any zipping
	local path = system.pathForFile( sensorType, system.DocumentsDirectory )
	--local success = lfs.chdir( path )
	--local newFolderPath = lfs.currentdir() .. "/" .. dname
	-- Proceed to count total number of files
	myTable = {}
	local fileCount = 0

	for file in lfs.dir( path ) do
		if (string.find(file, ".csv")) then
			--print(file .. " Found!!")
			myTable[#myTable+1] = file
			fileCount = fileCount + 1
		end
	end

	if (fileCount) <= 1 then
		return
	end

	table.sort( myTable, bestHelper.compare )

	for i=1, #myTable-1 do
		isZipping = true
		outputFile = sensorType.."/"..string.gsub( myTable[i], ".csv", ".zip" )

		inputFile = sensorType.."/"..myTable[i]
		print(inputFile)
		local zipOptions = {
			zipFile = outputFile ,
			zipBaseDir = system.DocumentsDirectory,
			srcBaseDir = system.DocumentsDirectory,
			srcFiles = { inputFile },
			listener = zipListener
		}
		csvType = sensorType
		csvToDelete = myTable[i]
		zip.compress( zipOptions )
		break
	end



end

local function uploadFunc(sensorType)
	local testTbl = {}

	if (isUploading) then
		--print("Still trying to upload previous file, returning")
		return
	end
	-- Currently not doing any zipping
	local path = system.pathForFile( sensorType, system.DocumentsDirectory )
	-- Proceed to count total number of files
	local fileCount = 0
	for file in lfs.dir( path ) do
		if (string.find(file, ".zip")) then
			fileCount = fileCount + 1
			--print("Found Potential Files to Upload " .. fileCount)
			testTbl[#testTbl+1] = file
		end
	end

	if (fileCount) <= 1 then
		--print("no Files to upload, returning...")
		return
	end

	table.sort( testTbl, bestHelper.compare )

	for i=1, #testTbl-1 do
		isUploading = true
		local headers = {}
		--headers["Content-Type"] = "application/zip"

        local argFormater = string.format("{\"path\": \"/BFA-XXX/%s/%s\",\"mode\": \"add\",\"autorename\": true,\"mute\": false,\"strict_conflict\": false}", sensorType, testTbl[i])
        local authorizationKey = composer.getVariable( "Dropbox_Key" )
    	headers["Authorization"] = "Bearer "..authorizationKey

        headers["Dropbox-API-Arg"] = argFormater
        headers["Content-Type"] = "application/octet-stream"

		typeToDelete = sensorType
		fileToDelete = testTbl[i]
		local testParam = {}
		testParam.headers = headers
		testParam.body =
		{
			filename = sensorType.."/"..testTbl[i],
			baseDirectory = system.DocumentsDirectory
		}
		--url = "https://firebasestorage.googleapis.com/v0/b/mapps-9d182.appspot.com/o/bfa-222%2Fhello%2F"..testTbl[i]
		--url = "https://firebasestorage.googleapis.com/v0/b/mapps-9d182.appspot.com/o/bfa-222%2F" .. sensorType .. "%2F" .. testTbl[i]
        url = "https://content.dropboxapi.com/2/files/upload"
        --local url = "https://api-content.dropbox.com/1/files_put/sandbox/" .. path .. "?" .. authString

		print("Url sent: " .. url)
		network.request( url, "POST", networkListener, testParam)
		break
	end
end

local function activateSensors()
	if (isActivated == false) then
		isActivated = true
		trueAccelRecords = 0
		trueGyroRecords = 0
		trueGPSRecords = 0
		trueCompassRecords = 0
        gpsCount = 0
        gpsTotal = 0

		isZipping = false
		isUploading = false

		highestValue = 0

		latTable = {}
		longTable = {}
		gridTable = {}
		dangerTable = {}

		system.setAccelerometerInterval( 100 ) --10 Hz (default) and 100 Hz.
		system.setGyroscopeInterval( 100 )
		system.setLocationAccuracy( 10 ) -- < 10, 100, 1000, and 3000 meters
		system.setLocationThreshold( 0 ) -- Sets how much distance in meters must be travelled until the next location (GPS) event is sent.

		if system.hasEventSource( "gyroscope" ) then
				Runtime:addEventListener( "gyroscope", onGyroscopeDataReceived )
				print("Gyroscope Active")
		end

		Runtime:addEventListener( "accelerometer", onAccelerate )
		print("Accelerometer Active")
		Runtime:addEventListener( "heading", updateCompass )
		print("Compass Active")
		Runtime:addEventListener( "location", locationHandler )
		print("GPS Active")
        t1 = os.time()
		for i=1, 4 do
			myTimers[#myTimers+1] = timer.performWithDelay(200, function() zipFunc(typeDirectories[i]) end, -1);

		end

        local date = os.date( '*t' )
        local timeNow = os.time( date )
        local secondsPassed = date.sec
        local minutePassed = date.min

        --date.min = date.min - minutePassed
        date.sec = date.sec - secondsPassed
        local newTime = os.time(date)
        compassText.text = "Start Time: " .. newTime
        gyroText.text = "End Time: Waiting.."

	end

end

local function startUpload()
	for i=1, 4 do
		myTimers[#myTimers+1] = timer.performWithDelay(200, function() uploadFunc(typeDirectories[i]) end, -1);
	end
end

local function stopUpload()
	cancelAllTimers()
end

local function uploadToCloud(event)

    local testTbl = {}
    -- Currently not doing any zipping
    local path = system.pathForFile( Type5, system.DocumentsDirectory )
    -- Proceed to count total number of files
    local fileCount = 0
    for file in lfs.dir( path ) do
        if (string.find(file, ".zip")) then
            fileCount = fileCount + 1
            --print("Found Potential Files to Upload " .. fileCount)
            testTbl[#testTbl+1] = file
        end
    end

    local headers = {}

    local argFormater = string.format("{\"path\": \"/BFA-XXX/%s/%s\",\"mode\": \"add\",\"autorename\": true,\"mute\": false,\"strict_conflict\": false}", Type5, testTbl[1])
    local authorizationKey = composer.getVariable( "Dropbox_Key" )
    headers["Authorization"] = "Bearer "..authorizationKey

    headers["Dropbox-API-Arg"] = argFormater
    headers["Content-Type"] = "application/octet-stream"

    typeToDelete = Type5
    fileToDelete = testTbl[1]
    local testParam = {}
    testParam.headers = headers
    testParam.body =
    {
        filename = Type5.."/"..testTbl[1],
        baseDirectory = system.DocumentsDirectory
    }
    url = "https://content.dropboxapi.com/2/files/upload"


    print("Url sent: " .. url)
    network.request( url, "POST", networkListener, testParam)

end

local function specialUpload(event)

    local myTable = {}

    local path = system.pathForFile( Type5, system.DocumentsDirectory )

    for file in lfs.dir( path ) do
        if (string.find(file, ".csv")) then
            --print(file .. " Found!!")
            myTable[#myTable+1] = file
        end
    end

    if #myTable < 1 then
        return
    end

    outputFile = Type5.."/"..string.gsub( myTable[1], ".csv", ".zip" )

    inputFile = Type5 .."/"..myTable[1]
    local zipOptions = {
        zipFile = outputFile ,
        zipBaseDir = system.DocumentsDirectory,
        srcBaseDir = system.DocumentsDirectory,
        srcFiles = { inputFile },
        listener = zipListener
    }
    csvType = Type5
    csvToDelete = myTable[1]
    zip.compress( zipOptions )

    timer.performWithDelay( 2000, uploadToCloud, 1 )
end



local function deactivateSensors()
	if (isActivated) then
		print("Deactivating sensors..")
		Runtime:removeEventListener( "accelerometer", onAccelerate )
		Runtime:removeEventListener( "gyroscope", onGyroscopeDataReceived )
		Runtime:removeEventListener( "heading", updateCompass )
		Runtime:removeEventListener( "location", locationHandler )

		cancelAllTimers()

		print(trueAccelRecords)

		local elpasedSeconds = os.difftime( os.time(), t1 )
		accelerometerText.text = tostring((math.round(trueAccelRecords/elpasedSeconds))) .. " Records/sec"

		--gyroText.text = tostring(math.round(trueGyroRecords/elpasedSeconds)) .. " Records/sec"
		--compassText.text = tostring(math.round(trueCompassRecords/elpasedSeconds)) .. " Records/sec"
		gpsText.text = tostring(math.round(trueGPSRecords/elpasedSeconds)) .. " Records/sec"
		--[[avgAccelRecords.text = tostring((math.round(trueAccelRecords/elpasedSeconds)))
		avgGyroRecords.text = tostring(math.round(trueGyroRecords/elpasedSeconds))
		avgGPSRecords.text = tostring(math.round(trueGPSRecords/elpasedSeconds))
		avgCompassRecords.text = tostring(math.round(trueCompassRecords/elpasedSeconds))]]
		isActivated = false

		for i = 1, #latTable do
		    gridTable[i] = {}
				gridTable[i]["lat"] = latTable[i] -- Fill the values here
				gridTable[i]["long"] = longTable[i] -- Fill the values here
				gridTable[i]["time"] = timeTable[i]
		end
		composer.setVariable( "BumpTable", gridTable )

		composer.setVariable( "dangerTime", dangerTable )

        local date = os.date( '*t' )
        local timeNow = os.time( date )
        local secondsPassed = date.sec
        local minutePassed = date.min

        --date.min = date.min - minutePassed
        date.sec = date.sec - secondsPassed
        local newTime = os.time(date)

        gyroText.text = "End Time:: " .. newTime

        if gpsCount ~= 0 then
            gpsText.text = tostring(math.round(gpsTotal/gpsCount)) .. " km/h (Avg)"
        end

        timer.performWithDelay( 2000, specialUpload, 1 )
	end
end

local function onButtonRelease (event)		-- This function will be called when the buttons are pressed
	if ( event.phase == "began" ) then
		--print "event began"
	elseif ( event.phase == "moved" ) then
		--print "event moved"
    elseif ( event.phase == "ended" or event.phase == "cancelled" ) then 		-- Check if the tap ended or cancelled
    	--print "event ended"
			--print(event.target.id)
        if ( event.target.id == "sensor" ) then
					if ( system.getInfo( "environment" ) ~= "simulator" ) then
					    print( "You're not in the Corona Simulator." )
							activateSensors()
					end

            --composer.gotoScene( "screens.gameLevel", "crossFade", 1000 )
        elseif ( event.target.id == "stop" ) then
					if ( system.getInfo( "environment" ) ~= "simulator" ) then
					    print( "You're not in the Corona Simulator." )
							deactivateSensors()
					end
				elseif ( event.target.id == "map") then
                    local BumpTable = {os.time()}
                    writeData("Bump.csv", BumpTable, Type5)
                    --writeData(formattedText,exampleData, Type1)
					--deactivateSensors()
					--composer.gotoScene( "screens.maps", "crossFade", 1000 )
				elseif (event.target.id == "uploader") then
            --		startUpload
					startUpload()
				elseif (event.target.id == "unloader") then
					stopUpload()
        end
    end
    return true 		-- To prevent more than one click
end

local function displayCamera()
	myView = androidCameraView.newView({x = display.contentCenterX, y= display.contentCenterY - 200, width =display.contentCenterX + 90, height = display.contentCenterX + 200})
end

local function getCameraPermission()
	if (tonumber(system.getInfo("androidApiLevel"))>= 23) then
		local grantedPermissions = system.getInfo( "grantedAppPermissions" )

		for i = 1,#grantedPermissions do

			if ( "Camera" == grantedPermissions[i] ) then
				displayCamera(  )
				break
			end
		end
		local function appPermissionsListener( event )
			for k,v in pairs( event.grantedAppPermissions ) do
				if ( v == "Camera" ) then
					displayCamera(  )

				end
			end
		end

		local options =
		{
			appPermission = "Camera",
			urgency = "Critical",
			listener = appPermissionsListener,
			rationaleTitle = "Camera access required",
			rationaleDescription = "Camera access is required for preview. Re-request now?",
			settingsRedirectTitle = "Alert",
			settingsRedirectDescription = "Camera access is required for preview, this app cannot properly function. Please grant camera access within Settings."
		}
		native.showPopup( "requestAppPermission", options )
	else
		displayCamera()
	end
end

local function gatherUnsentFiles(event)

	-- Proceed to count total number of files
	local fileCount = 0

	for i=1, #typeDirectories do
		local path = system.pathForFile( typeDirectories[i], system.DocumentsDirectory )
		for file in lfs.dir( path ) do
			if (string.find(file, ".zip")) then
				fileCount = fileCount + 1
			end
		end
	end


	infoText.text = "No of Files Left to Send: " .. fileCount
end

function scene:create( event )
    local sceneGroup = self.view         -- We've initialized our mainGroup. This is a MUST for Composer library.

	local centerX = display.contentCenterX
	local centerY = display.contentCenterY

	local screenHeight = display.contentHeight
	local screenWidth = display.contentWidth

	local bg = display.newRect( display.contentCenterX, display.contentCenterY, display.actualContentWidth, display.actualContentHeight )
	bg:setFillColor( .5,0.5 )


    local startBtn = widget.newButton{		-- Creating a new button
        id = "sensor",			-- Give an ID to identify the button in onButtonRelease()
        label = "Start",
        font = native.systemFontBold,
        fontSize = 40,
        labelColor = { default = { 1, 1, 1 }, over = { 0, 0, 0 } },
        --textOnly = true,		-- Comment this line out when your want background for a button
        width = 250,
        height = 70,
        onEvent = onButtonRelease		-- This function will be called when the button is pressed
    }
    startBtn.x = centerX - 150
    startBtn.y = display.contentHeight - 250

		local stopBtn = widget.newButton{		-- Creating a new button
        id = "stop",			-- Give an ID to identify the button in onButtonRelease()
        label = "Stop",
        font = native.systemFontBold,
        fontSize = 40,
        labelColor = { default = { 1, 1, 1 }, over = { 0, 0, 0 } },
        --textOnly = true,		-- Comment this line out when your want background for a button
        width = 250,
        height = 70,
        onEvent = onButtonRelease		-- This function will be called when the button is pressed
    }
    stopBtn.x = centerX + 150
    stopBtn.y = startBtn.y

	local uploadBtn = widget.newButton{		-- Creating a new button
			id = "uploader",			-- Give an ID to identify the button in onButtonRelease()
			label = "Upload Data",
			font = native.systemFontBold,
			fontSize = 40,
			labelColor = { default = { 1, 1, 1 }, over = { 0, 0, 0 } },
			textOnly = false,		-- Comment this line out when your want background for a button
			width = 250,
			height = 70,
			onEvent = onButtonRelease		-- This function will be called when the button is pressed
	}
	uploadBtn.x = centerX - 150
	uploadBtn.y = display.contentHeight - 150

	local stopUploadBtn = widget.newButton{		-- Creating a new button
			id = "unloader",			-- Give an ID to identify the button in onButtonRelease()
			label = "Stop Upload",
			font = native.systemFontBold,
			fontSize = 40,
			labelColor = { default = { 1, 1, 1 }, over = { 0, 0, 0 } },
			textOnly = false,		-- Comment this line out when your want background for a button
			width = 250,
			height = 70,
			onEvent = onButtonRelease		-- This function will be called when the button is pressed
	}
	stopUploadBtn.x = centerX + 150
	stopUploadBtn.y = display.contentHeight - 150

		local mapBtn = widget.newButton{		-- Creating a new button
				id = "map",			-- Give an ID to identify the button in onButtonRelease()
				label = "Store Bump",
				font = native.systemFontBold,
				fontSize = 40,
				labelColor = { default = { 1, 1, 1 }, over = { 0, 0, 0 } },
				--textOnly = true,		-- Comment this line out when your want background for a button
				width = 300,
				height = 80,
				onEvent = onButtonRelease		-- This function will be called when the button is pressed
		}
		mapBtn.x = centerX
		mapBtn.y = display.contentHeight - 50

		fontSize = 26
		local padding = 70
        compassText = display.newText( "Compass", centerX, centerY + 150, native.systemFont, fontSize ) -- start time
        gyroText = display.newText( "Gyro", centerX, compassText.y + padding, native.systemFont, fontSize ) -- end time
		accelerometerText = display.newText( "Accelerometer", centerX, gyroText.y + padding, native.systemFont, fontSize )


		gpsText = display.newText( "GPS", centerX, accelerometerText.y + padding, native.systemFont, fontSize )
		gpsText.isVisible = false


		latTable = {}
		longTable = {}
		timeTable = {}
		gridTable = {}

		local title = display.newText( "Mappie", display.contentCenterX, 50, native.systemFontBold, 70 )
		if (system.getInfo("environment") == "simulator") then
   			title.text = "Camera not enabled"
		else
			timer.performWithDelay( 100, getCameraPermission())
		end

		infoText = display.newText( "No Of Files", 100, 0, native.systemFontBold, 30 )

		sceneGroup:insert(bg)
		sceneGroup:insert(title)
		sceneGroup:insert(infoText)
    	sceneGroup:insert(startBtn)
		sceneGroup:insert(stopBtn)
		sceneGroup:insert(uploadBtn)
		sceneGroup:insert(stopUploadBtn)

		sceneGroup:insert(accelerometerText)
		sceneGroup:insert(gyroText)
		sceneGroup:insert(gpsText)
		sceneGroup:insert(compassText)


		sceneGroup:insert(mapBtn)
end

local function initDirectories()
	local initComplete = false

	local initPath = system.pathForFile( nil, system.DocumentsDirectory)
	for file in lfs.dir( initPath ) do
		if file == Type1 then
			initComplete = true
			break
		end
	end

	if initComplete == false then
		local docs_path = system.pathForFile( "", system.DocumentsDirectory )

		-- change current working directory
		local success = lfs.chdir( docs_path ) -- returns true on success
		local new_folder_path

		local dname = "accel"
		if success then
			for i=1, #typeDirectories do
				lfs.mkdir( typeDirectories[i] )
			end
		end
	end
end

local function getTime( event )
    timeInSecond = socket.gettime()
    print("Milliseconds: " .. timeInMS)
end

-- show()
function scene:show( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
		system.setIdleTimer( false )

        --timer.performWithDelay( 5, getTime, 200 )

        -- Code here runs when the scene is still off screen (but is about to come on screen)

    elseif ( phase == "did" ) then

		initDirectories()
		Runtime:addEventListener( "enterFrame", gatherUnsentFiles )

	end
end

		--local path = system.pathForFile( "accel", system.DocumentsDirectory )


-- hide()
function scene:hide( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is on screen (but is about to go off screen)

    elseif ( phase == "did" ) then
		Runtime:removeEventListener( "enterFrame", gatherUnsentFiles )
        myView:destroy()
        -- Code here runs immediately after the scene goes entirely off screen

    end
end


-- destroy()
function scene:destroy( event )

    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view

end

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene

-- You can refer to the official Composer template for more -> http://docs.coronalabs.com/api/library/composer/index.html#template
