[![Build Status](https://travis-ci.org/britzl/defold-googleanalytics.svg?branch=master)](https://travis-ci.org/britzl/defold-googleanalytics)

# Google Analytics for Defold
This is a Lua implementation of [Google Analytics](https://www.google.com/analytics) for the [Defold game engine](http://www.defold.com). The project is provided as a Defold library project for easy integration into Defold games. The implementation is loosely based on the design of the Google Analytics Android SDK, but with several simplifications thanks to the dynamic and flexible nature of Lua.

This Lua implementation uses the [Google Analytics Measurement Protocol](https://developers.google.com/analytics/devguides/collection/protocol/v1/) to make direct calls to the Google Analytics servers. On top of these raw calls the implementation also adds support for offline tracking, automatic crash/exception reporting and automatic retrieval of relevant tracking parameters such as app name, app id, language, screen resolution and so on.

## Installation
You can use Google Analytics in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

	https://github.com/britzl/defold-googleanalytics/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/defold-googleanalytics/releases).

## Configuration
Before you can use Google Analytics in your project you need to add your analytics tracking ID to game.project. Open game.project as a text file and create a new section:

	[googleanalytics]
	tracking_id = UA-1234567-1

Additional optional values are:

	[googleanalytics]
	dispatch_period = 1800
	queue_save_period = 60
	verbose = 1

`dispatch_period` is the interval, in seconds, at which tracking data is sent to the server.

`queue_save_period` is the minimum interval, in seconds, at which tracking data is saved to disk.

`verbose` set to 1 will print some additional data about when and how many hits are sent to Google Analytics. Set to 0 or omit the value to not print anything.

## Usage
Once you have added your tracking ID to game.project you're all set to start sending tracking data:

	local ga = require "googleanalytics.ga"

	function init(self)
		ga.get_default_tracker().screenview("my_cool_screen")
	end

	function update(self, dt)
		ga.update()
	end

	function on_input(self, action_id, action)
		if gui.pick_node(node1, action.x, action.y) and action.pressed then
			go.get_default_tracker().event("category", "action")
		end

		if gui.pick_node(node2, action.x, action.y) and action.pressed then
			local time = socket.gettime()
			http.request("http://d.defold.com/stable/info.json", "GET", function(self, id, response)
				local millis = math.floor((socket.gettime() - time) * 1000)
				go.get_default_tracker().timing("http", "get", millis)
			end)
		end
	end
	
## Supported hit types
This implementation supports the following hit types:

* Event - `ga.get_default_tracker().event()`
* Screen View - `ga.default_tracker().screenview()`
* Timing - `ga.default_tracker().timing()`
* Exception - `ga.default_tracker().exception()`, also see section on automatic crash/exception tracking

You can also register a raw hit where you specify all parameters yourself:

	ga.get_default_tracker().raw("v=1&tid=UA-123456-1&cid=5555&t=pageview&dp=%2Fpage")

### Automatic crash/exception tracking
You can let Google Analytics automatically send tracking data when your app crashes. The library can handle soft crashes (ie when your Lua code crashes) using [sys.set_error_handler](http://www.defold.com/ref/sys/#sys.set_error_handler:error_handler) and hard crashes (ie when the Defold engine crashes) using [crash API](http://www.defold.com/ref/crash/). Enable automatic crash tracking like this:

	local ga = require "googleanalytics.ga"
	
	function init(self)
		ga.get_default_tracker().enable_crash_reporting(true)
	end

## License
This library is released under the same [Terms and Conditions as the Defold editor and service itself](http://www.defold.com/about-terms/).

## Third party tools and modules used
The library uses the following modules:

* [json.lua by rxi](https://github.com/rxi/json.lua) (MIT License)
* [uuid.lua by Tieske](https://github.com/Tieske/uuid) (Apache 2.0)
* [url_encode() from Lua String Recipes](http://lua-users.org/wiki/StringRecipes)

The example project uses:

* [Dirty Larry UI library](https://github.com/andsve/dirtylarry)
* [Spineboy animation from the Spine animation tool](https://github.com/EsotericSoftware/spine-superspineboy).
