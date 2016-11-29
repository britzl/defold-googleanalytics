local mock = require "deftest.mock"
local mock_fs = require "deftest.mock.fs"
local mock_time = require "deftest.mock.time"
local file = require "googleanalytics.internal.file"

return function()
	local queue
	local http_history = {}
	
	describe("queue", function()
		before(function()
			queue = require "googleanalytics.internal.queue"
			mock.mock(http)
			mock_fs.mock()
			mock_time.mock()
			http.request.replace(function(url, method, callback, headers, post_data, options)
				table.insert(http_history, { url = url, method = method, callback = callback, headers = headers, post_data = post_data, options = options })
				if callback then
					callback({}, "id", { status = 200, response = "", headers = {} })
				end
			end)
		end)

		after(function()
			package.loaded["googleanalytics.internal.queue"] = nil
			mock.unmock(http)
			mock_fs.unmock()
			mock_time.unmock()
		end)

		it("should be able to add params", function()
			queue.add("foo=bar")
		end)

		it("should be saving added params to disk", function()
			mock_time.set(100)
			local filename = file.get_save_file_name("__ga_queue")
			queue.add("foo=bar")
			assert(mock_fs.has_file(filename))
			assert(queue.last_save_time == 100)
			
			-- nothing will happen the next time we add something
			queue.add("foo=car")
			assert(queue.last_save_time == 100)
			mock_time.elapse(queue.minimum_save_period)
			
			-- and nothing will happen even if we elapsed the time
			assert(queue.last_save_time == 100)
			
			-- we need to add something more before the queue is written to disk
			queue.add("foo=dar")
			assert(queue.last_save_time == 100 + queue.minimum_save_period)
		end)
		
		it("should not accept very large param strings", function()
			local filename = file.get_save_file_name("__ga_queue")
			local large = ("x"):rep(1 + 8 * 1024)
			queue.add(large)
			assert(not mock_fs.has_file(filename))
			assert(not queue.last_save_time)
		end)
		
		it("should be sending added params to Google Analytics", function()
			queue.add("a=b")
			queue.add("c=d")
			queue.add("e=f")
			assert(#http_history == 0)
			queue.dispatch()
			assert(#http_history == 1)
			assert(http_history[1].post_data == "a=b&qt=0\nc=d&qt=0\ne=f&qt=0")
		end)
	end)
end