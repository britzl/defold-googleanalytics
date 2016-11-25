local tracker = require "googleanalytics.tracker"
local queue = require "googleanalytics.internal.queue"

local M = {}

local default_tracker = nil


--- Get the default tracker
-- @return Tracker instance
function M.get_default_tracker()
	if not default_tracker then
		local tracking_id = sys.get_config("googleanalytics.tracking_id")
		assert(tracking_id, "You must set tracking_id in section [googleanalytics] in game.project before using this module")
		default_tracker = tracker.create(tracking_id)
	end
	return default_tracker
end

--- Dispatch hits to Google Analytics
function M.dispatch()
	queue.dispatch()
end

--- Update the Google Analytics module.
-- This will check if automatic dispatch of hits are enabled and if so, if it is
-- time to dispatch stored hits.
function M.update()
	-- manual dispatch only?
	if dispatch_period <= 0 then
		return
	end
	
	if not queue.last_dispatch_time or (socket.gettime() >= (queue.last_dispatch_time + dispatch_period)) then 
		M.dispatch()
	end
end


return M