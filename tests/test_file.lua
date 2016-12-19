local mock_fs = require "deftest.mock.fs"
local file = require "googleanalytics.internal.file"

return function()
	describe("file", function()
		local file
	
		before(function()
			mock_fs.mock()
			file = require "googleanalytics.internal.file"
		end)

		after(function()
			mock_fs.unmock()
			package.loaded["googleanalytics.internal.file"] = nil
		end)

		it("should be able to provide a full path to a save file", function()
			assert(file.get_save_file_name("foobar"))
		end)

		it("should be able write to a file", function()
			local name1 = "foo"
			local name2 = "bar"
			file.save(name1, "some data")
			file.save(name2, "some other data")

			assert(mock_fs.has_file(file.get_save_file_name(name1)))
			assert(mock_fs.has_file(file.get_save_file_name(name2)))
			assert(mock_fs.get_file(file.get_save_file_name(name1)) == "some data")
			assert(mock_fs.get_file(file.get_save_file_name(name2)) == "some other data")
		end)

		it("should write to a temporary file and then move it if successful", function()
			file.save("foobar", "some data")

			assert(os.rename.calls == 1)
			assert(os.remove.calls == 1)
		end)

		it("should not write a partial file to disk", function()
			file.save("foobar", "some data")
			mock_fs.fail_writes(true)
			assert_error(function() file.save("foobar", "some other data") end)
			
			assert(mock_fs.get_file(file.get_save_file_name("foobar")) == "some data")
		end)

		it("should be able to load an existing file", function()
			local name1 = "foo"
			local name2 = "bar"
			file.save(name1, "some data")
			file.save(name2, "some other data")
			
			assert(file.load(name1) == "some data")
			assert(file.load(name2) == "some other data")
		end)

		it("should not crash when loading a file that does not exist", function()
			local data, err = file.load("foobar")
			assert(not data and err)
		end)
	end)
end