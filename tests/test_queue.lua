local mock = require "deftest.mock"
local mock_fs = require "deftest.mock.fs"
local mock_time = require "deftest.mock.time"
local file = require "googleanalytics.internal.file"

return function()
	local queue
	local http_history
	local http_status = 200
	
	describe("queue", function()
		before(function()
			http_history = {}
			http_status = 200
			mock.mock(http)
			mock_fs.mock()
			mock_time.mock()
			http.request.replace(function(url, method, callback, headers, post_data, options)
				table.insert(http_history, { url = url, method = method, callback = callback, headers = headers, post_data = post_data, options = options })
				if callback then
					callback({}, "id", { status = http_status, response = "", headers = {} })
				end
			end)
			queue = require "googleanalytics.internal.queue"
		end)

		after(function()
			mock.unmock(http)
			mock_fs.unmock()
			mock_time.unmock()
			package.loaded["googleanalytics.internal.queue"] = nil
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
		
		it("should be sending added params to Google Analytics", function()
			queue.add("a=b")
			queue.add("c=d")
			queue.add("e=f")
			assert(#http_history == 0)
			queue.dispatch()
			assert(#http_history == 1)
			assert(http_history[1].post_data == "a=b&qt=0\nc=d&qt=0\ne=f&qt=0")
		end)
		
		it("should add queue time before sending to Google Analytics", function()
			mock_time.set(100)
			queue.add("a=b")
			mock_time.set(110)
			queue.add("c=d")
			mock_time.set(120)
			queue.add("e=f")
			
			mock_time.elapse(300)
			queue.dispatch()
			assert(#http_history == 1)
			assert(http_history[1].post_data == "a=b&qt=320000\nc=d&qt=310000\ne=f&qt=300000")
		end)
		
		it("should not accept very large param strings", function()
			local filename = file.get_save_file_name("__ga_queue")
			
			-- this first very large hit should be completely ignored
			local large = ("x"):rep(1 + 8 * 1024)
			queue.add(large)
			assert(not mock_fs.has_file(filename))
			assert(not queue.last_save_time)
			
			-- a small hit should be writte to disk
			queue.add("a=b")
			assert(mock_fs.has_file(filename))
			assert(queue.last_save_time)

			-- the small hit should be sent to Google
			queue.dispatch()
			assert(#http_history == 1)
			assert(http_history[1].post_data == "a=b&qt=0")
		end)
		
		it("should limit the size of the total http payload", function()
			local large = "a=" .. ("x"):rep(8000)
			queue.add(large)	-- first batch
			queue.add(large)	-- first batch
			queue.add(large)	-- second batch

			queue.dispatch()

			assert(#http_history == 2)
			assert(http_history[1].post_data == large .. "&qt=0\n" .. large .. "&qt=0")
			assert(http_history[2].post_data == large .. "&qt=0")
		end)
		
		it("should send 20 params per http request", function()
			local post_data1 = {}
			for i=1,20 do
				queue.add("a=b")
				table.insert(post_data1, "a=b&qt=0")
			end
			local post_data2 = {}
			for i=1,10 do
				queue.add("a=b")
				table.insert(post_data2, "a=b&qt=0")
			end
			
			queue.dispatch()
			assert(#http_history == 2)
			assert(http_history[1].post_data == table.concat(post_data1, "\n"))
			assert(http_history[2].post_data == table.concat(post_data2, "\n"))
		end)
		
		it("should not throw away data when http request fails", function()
			queue.add("a=b")
			queue.add("c=d")
			queue.add("e=f")
			
			http_status = 500
			queue.dispatch()
			assert(#http_history == 1)
			assert(http_history[1].post_data == "a=b&qt=0\nc=d&qt=0\ne=f&qt=0")

			mock_time.elapse(300)
			queue.add("g=h")
			http_status = 200
			queue.dispatch()
			assert(#http_history == 2)
			assert(http_history[2].post_data == "a=b&qt=300000\nc=d&qt=300000\ne=f&qt=300000\ng=h&qt=0")
		end)
	end)
end