--screens.gameLevel

local composer = require ("composer")       -- Include the Composer library. Please refer to -> http://docs.coronalabs.com/api/library/composer/index.html
local scene = composer.newScene()           -- Created a new scene

local variableText = composer.getVariable( "variableString" )		-- Get the variable "variableString" defined in main.lua
local fontSize = composer.getVariable( "fontSize" )		-- Get the variable "fontSize" defined in main.lua
local widget = require ("widget")
local mymap

local function markerListener(event)
    print( "type: ", event.type )  -- event type
    print( "markerId: ", event.markerId )  -- ID of the marker that was touched
    print( "lat: ", event.latitude )  -- latitude of the marker
    print( "long: ", event.longitude )  -- longitude of the marker
end

local function changeScene(event)
	if ( event.phase == "began" ) then
		print "event began"
	elseif ( event.phase == "moved" ) then
		print "event moved"
  elseif ( event.phase == "ended" or event.phase == "cancelled" ) then 		-- Check if the tap ended or cancelled
    print "event ended"
    composer.gotoScene( "screens.mainMenu", "crossFade", 1000 )

  end
  return true 		-- To prevent more than one click

    -- For more information about events, please refer to the following documents
    -- http://docs.coronalabs.com/api/event/index.html
    -- http://docs.coronalabs.com/guide/index.html#events-and-listeners
end

function scene:create( event )
    local sceneGroup = self.view         -- We've initialized our mainGroup. This is a MUST for Composer library.

		local centerX = display.contentCenterX
		local centerY = display.contentCenterY
		local width = display.contentWidth
		local height = display.contentHeight

		local backBtn = widget.newButton{		-- Creating a new button
				id = "stop",			-- Give an ID to identify the button in onButtonRelease()
				label = "Back",
				font = native.systemFontBold,
				fontSize = 64,
				labelColor = { default = { 1, 1, 1 }, over = { 0, 0, 0 } },
				textOnly = true,		-- Comment this line out when your want background for a button
				width = 372,
				height = 158,
				onEvent = changeScene		-- This function will be called when the button is pressed
		}
		backBtn.x = centerX - 200
		backBtn.y = 99

		local errorTxt = display.newText( "No Error Log", centerX, height-100, native.systemFont, 50 )

		local options =
		{
    		title = "Displayed Title",
    		subtitle = "Subtitle text",
    		imageFile =  "assets/custom1.png",
		}

		local options2 =
		{
			title = "Displayed Title",
			subtitle = "Subtitle text",
			imageFile =  "assets/custom2.png",
		}

		local bumpsDetected = 0
		local nonBumps = 0

		if ( system.getInfo( "environment" ) ~= "simulator" ) then
				local hello = composer.getVariable("BumpTable")
				local bye = composer.getVariable("dangerTime")
				myMap = native.newMapView( 0, 0, width-50, width-50 ) --lat long
				myMap.x = centerX
				myMap.y = centerY
				myMap.mapType = "standard"
				myMap:setCenter( hello[1].lat, hello[1].long )

				local isBump
				for i=1, #hello do --loop over gps table

					isBump = false

					for x=1, #bye do --loop over bump table
						if (hello[i].time == bye[x]) then
							isBump = true -- time matched, get out
							break
						end
					end

					-- check bumps
					if (isBump) then --time match
						bumpsDetected = bumpsDetected + 1
						timer.performWithDelay( 2000, function()
						myMap:addMarker( hello[i].lat, hello[i].long, options2)
						end)
					end

				end
			errorTxt.text = " Bump:" .. bumpsDetected
		end


		sceneGroup:insert(backBtn)
		sceneGroup:insert(errorTxt)
		sceneGroup:insert(myMap)
end


function scene:show( event )
    local phase = event.phase

    if ( phase == "will" ) then         -- Scene is not shown entirely

    elseif ( phase == "did" ) then      -- Scene is fully shown on the screen

    end
end


function scene:hide( event )
    local phase = event.phase

    if ( phase == "will" ) then         -- Scene is not off the screen entirely

        --cleanUp()       -- Clean up the scene from timers, transitions, listeners
				if myMap ~= nil then
					myMap:removeSelf()
					myMap = nil

    elseif ( phase == "did" ) then      -- Scene is off the screen

				end
    end
end

function scene:destroy( event )
    -- Called before the scene is removed
end

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene

-- You can refer to the official Composer template for more -> http://docs.coronalabs.com/api/library/composer/index.html#template
