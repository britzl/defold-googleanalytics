local mock = require "deftest.mock.mock"
local mock_fs = require "deftest.mock.fs"
local file = require "googleanalytics.internal.file"


return function()
	local tracker
	local queue
	local queue_params
	
	local function split_params(hit)
		local params = {}
		for param in hit:gmatch("[^&]+") do
			local k,v  = param:match("(.*)=(.*)")
			params[k] = v
		end
		return params
	end
	
	describe("tracker", function()
		before(function()
			mock_fs.mock()
			mock.mock(sys)
			tracker = require "googleanalytics.tracker"
			queue = require "googleanalytics.internal.queue"
			
			queue_params = {}
			mock.mock(queue)
			queue.add.replace(function(params)
				table.insert(queue_params, params)
			end)
		end)

		after(function()
			mock_fs.unmock()
			mock.unmock(queue)
			mock.unmock(sys)
			package.loaded["googleanalytics.tracker"] = nil
			package.loaded["googleanalytics.internal.queue"] = nil
		end)

		it("should be able to create new instances", function()
			assert_error(function() tracker.create() end)
			
			local instance1 = tracker.create("UA-87977671-1")
			local instance2 = tracker.create("UA-87977671-1")
			assert(instance1 ~= instance2)
		end)

		it("should require a tracking id when created", function()
			assert_error(function() tracker.create() end)
		end)

		it("should persist an uuid", function()
			local t = tracker.create("UA-87977671-1")
			local filename = file.get_save_file_name("__ga_uuid")
			assert(mock_fs.has_file(filename))
			local uuid = mock_fs.get_file(filename)

			local t = tracker.create("UA-87977671-1")
			assert(mock_fs.get_file(filename) == uuid)
		end)

		it("should have some base parameters", function()
			local t = tracker.create("UA-87977671-1")
			local params = split_params(t.base_params)
			local sys_info = sys.get_sys_info()
			assert(params.v == "1")
			assert(params.ds == "app")
			assert(params.vp == sys.get_config("display.width") .. "x" .. sys.get_config("display.height"))
			assert(params.ul == sys.get_sys_info().device_language)
			assert(params.tid == "UA-87977671-1")
			assert(params.av == sys.get_config("project.version"))
			assert(params.aid)
			assert(params.an)
			assert(params.cid:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") == params.cid)
		end)
		
		it("should be able to add raw hits", function()
			local t = tracker.create("UA-87977671-1")
			assert_error(function() t.raw() end)

			t.raw("a=b&c=d")
			assert(#queue_params == 1)
			assert(queue_params[1] == "a=b&c=d")
		end)
		
		it("should be able to add events", function()
			local t = tracker.create("UA-87977671-1")
			assert_error(function() t.event(nil, "action1") end)
			assert_error(function() t.event("category1") end)
			assert_error(function() t.event("", "action1") end)
			assert_error(function() t.event("category1", "") end)
			assert_error(function() t.event("category1", "action1", nil, -1) end)

			t.event("category1", "action1")
			t.event("category2", "action2", "label2")
			t.event("category3", "action3", "label3", 150)
			assert(#queue_params == 3)
			assert(queue_params[1] == t.base_params .. "&t=event&ec=category1&ea=action1")
			assert(queue_params[2] == t.base_params .. "&t=event&ec=category2&ea=action2&el=label2")
			assert(queue_params[3] == t.base_params .. "&t=event&ec=category3&ea=action3&el=label3&ev=150")
		end)
		
		it("should be able to add exceptions", function()
			local t = tracker.create("UA-87977671-1")
			t.exception()
			t.exception(nil, true)
			t.exception("description1")
			t.exception("description2", false)
			t.exception("description3", true)
			assert(#queue_params == 5)
			assert(queue_params[1] == t.base_params .. "&t=exception")
			assert(queue_params[2] == t.base_params .. "&t=exception&exf=1")
			assert(queue_params[3] == t.base_params .. "&t=exception&exd=description1")
			assert(queue_params[4] == t.base_params .. "&t=exception&exf=0&exd=description2")
			assert(queue_params[5] == t.base_params .. "&t=exception&exf=1&exd=description3")
		end)
		
		it("should be able to add screen views", function()
			local t = tracker.create("UA-87977671-1")
			assert_error(function() t.screenview() end)
			
			t.screenview("screen1")
			t.screenview("screen2")
			assert(#queue_params == 2)
			assert(queue_params[1] == t.base_params .. "&t=screenview&cd=screen1")
			assert(queue_params[2] == t.base_params .. "&t=screenview&cd=screen2")
		end)
		
		it("should be able to add timings", function()
			local t = tracker.create("UA-87977671-1")
			assert_error(function() t.timing(nil, "variable1", 10) end)
			assert_error(function() t.timing("category1", nil, 10) end)
			assert_error(function() t.timing("category1", "variable1") end)
			assert_error(function() t.timing("category1", "variable1", -1) end)
			
			t.timing("category1", "variable1", 10)
			t.timing("category2", "variable2", 20, "label2")
			assert(#queue_params == 2)
			assert(queue_params[1] == t.base_params .. "&t=timing&utc=category1&utv=variable1&utt=10")
			assert(queue_params[2] == t.base_params .. "&t=timing&utc=category2&utv=variable2&utt=20&utl=label2")
		end)
		
		it("should be able to enable automatic hard crash reporting", function()
			if not crash then
				return
			end
			local t = tracker.create("UA-87977671-1")
			crash.write_dump()
			t.enable_crash_reporting(true)

			assert(#queue_params == 1)
			local params = split_params(queue_params[1])
			assert(params.exf == "1") -- fatal
			assert(params.exd)
		end)

		it("should be able to enable automatic soft crash reporting", function()
			if not crash then
				return
			end
			local soft_crash
			sys.set_error_handler.replace(function(handler)
				soft_crash = handler
			end)

			local t = tracker.create("UA-87977671-1")
			t.enable_crash_reporting(true)
			soft_crash("lua", "message", "traceback")

			assert(#queue_params == 1)
			local params = split_params(queue_params[1])
			assert(params.exf == "0") -- non-fatal
			assert(params.exd == "message")
			assert(params.exd)
		end)

		it("should be able to forward hard crashes when automatic crash reporting is enabled", function()
			if not crash then
				return
			end

			local on_hard_crash_invoked = false
			local function on_hard_crash() on_hard_crash_invoked = true end

			local t = tracker.create("UA-87977671-1")
			crash.write_dump()
			t.enable_crash_reporting(true, nil, on_hard_crash)

			assert(#queue_params == 1)
			local params = split_params(queue_params[1])
			assert(params.exf == "1")
			assert(params.exd)
			assert(on_hard_crash_invoked)
		end)

		it("should be able to forward soft crashes when automatic crash reporting is enabled", function()
			if not crash then
				return
			end

			local on_soft_crash_invoked = false
			local function on_soft_crash() on_soft_crash_invoked = true end

			local soft_crash
			sys.set_error_handler.replace(function(handler)
				soft_crash = handler
			end)

			local t = tracker.create("UA-87977671-1")
			t.enable_crash_reporting(true, on_soft_crash, nil)
			soft_crash("lua", "message", "traceback")

			assert(#queue_params == 1)
			local params = split_params(queue_params[1])
			assert(params.exf == "0") -- non-fatal
			assert(params.exd == "message")
			assert(params.exd)
			assert(on_soft_crash_invoked)
		end)
	end)
end