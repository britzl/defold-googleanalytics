local mock = require "deftest.mock.mock"
local mock_fs = require "deftest.mock.fs"
local mock_time = require "deftest.mock.time"
local file = require "googleanalytics.internal.file"

return function()
	local ga
	local queue
	local tracker
	
	describe("ga", function()
		local mocked_sys_config_values = {}
		local function mock_sys_config_value(key, value)
			mocked_sys_config_values[key] = value
		end
	
		before(function()
			mock.mock(sys)
			mock_fs.mock()
			mock_time.mock()

			ga = require "googleanalytics.ga"
			tracker = require "googleanalytics.tracker"
			queue = require "googleanalytics.internal.queue"
			mock.mock(queue)
			mock.mock(tracker)
			--queue.dispatch.replace(function() end)
			sys.get_config.replace(function(key, default)
				local value = mocked_sys_config_values[key]
				if value and type(value) == "string" then
					return value
				elseif value ~= nil and type(value) ~= "string" then
					return default
				else
					return sys.get_config.original(key, default)
				end
			end)
		end)

		after(function()
			mock.unmock(sys)
			mock.unmock(queue)
			mock.unmock(tracker)
			mock_fs.unmock()
			mock_time.unmock()
			
			package.loaded["googleanalytics.internal.queue"] = nil
			package.loaded["googleanalytics.ga"] = nil
			package.loaded["googleanalytics.tracker"] = nil
		end)

		it("has a default tracker instance", function()
			local t = ga.get_default_tracker()
			assert(t)
			assert(ga.get_default_tracker() == t)
		end)

		it("should read tracking id from game.project", function()
			mock_sys_config_value("googleanalytics.tracking_id", "UA-123456-7")
		
			local t = ga.get_default_tracker()
			assert(t)
			assert(tracker.create.params[1] == "UA-123456-7")
		end)

		it("should read dispatch period from game.project", function()
			mock_sys_config_value("googleanalytics.dispatch_period", "12345")
		
			package.loaded["googleanalytics.ga"] = nil
			ga = require "googleanalytics.ga"
			assert(ga.dispatch_period == 12345)
		end)

		it("should use a default dispatch period if none is provided game.project", function()
			mock_sys_config_value("googleanalytics.dispatch_period", false)
		
			package.loaded["googleanalytics.ga"] = nil
			ga = require "googleanalytics.ga"
			assert(ga.dispatch_period == 30 * 60)
		end)

		it("should let the queue dispatch hits at regular intervals", function()
			mock_time.set(0)
			ga.update()
			assert(queue.dispatch.calls == 1)
			ga.update()
			assert(queue.dispatch.calls == 1)

			mock_time.elapse(ga.dispatch_period)
			
			ga.update()
			assert(queue.dispatch.calls == 2)
		end)

		it("should not automatically dispatch hits if set to manually dispatch them", function()
			ga.dispatch_period = 0
			ga.update()
			assert(queue.dispatch.calls == 0)
		end)
	end)
end