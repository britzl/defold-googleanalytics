return function()
	local uuid_generator
	
	describe("uuid", function()
		before(function()
			uuid_generator = require "googleanalytics.internal.uuid"
		end)

		after(function()
			package.loaded["googleanalytics.internal.uuid"] = nil
		end)

		it("should generate uuids", function()
			uuid_generator.seed()
			local uuid = uuid_generator()
			assert(uuid)
			-- d902fd39-bbd3-41ad-c1e9--0ee49473f3e0
			assert(uuid:match("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") == uuid)
		end)
	end)
end