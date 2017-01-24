local mock = require "deftest.mock"
local user_agent = require "googleanalytics.internal.user_agent"

return function()
	describe("user_agent", function()

		local mocked_values
	
		before(function()
			mock.mock(sys)
			mocked_values = {}
			sys.get_sys_info.replace(function()
				local sys_info = sys.get_sys_info.original()
				for k,v in pairs(mocked_values) do
					sys_info[k] = v
				end
				return sys_info
			end)
		end)

		after(function()
			mock.unmock(sys)
		end)

		it("should be able to provide user agent strings for all platforms", function()
			mocked_values["system_name"] = "iPhone OS"
			mocked_values["device_model"] = "iPhone5,0"
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(iPhone;.*") == uas)

			mocked_values["system_name"] = "iPhone OS"
			mocked_values["device_model"] = "iPad5,0"
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(iPad;.*") == uas)

			mocked_values["system_name"] = "iPhone OS"
			mocked_values["device_model"] = "iPod5,0"
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(iPod;.*") == uas)

			mocked_values["system_name"] = "Android"
			mocked_values["device_model"] = nil
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(Linux;.*") == uas)

			mocked_values["system_name"] = "Darwin"
			mocked_values["device_model"] = nil
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(Macintosh;.*") == uas)

			mocked_values["system_name"] = "Darwin"
			mocked_values["device_model"] = nil
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(Macintosh;.*") == uas)
		end)

		it("should provide no user agent string for HTML5", function()
			mocked_values["system_name"] = "HTML5"
			mocked_values["device_model"] = nil
			local uas = user_agent.get()
			assert(not uas)
		end)

		it("should be able to handle unknown system names", function()
			mocked_values["system_name"] = "Foobar"
			mocked_values["device_model"] = nil
			local uas = user_agent.get()
			assert(uas and uas:match("Mozilla%/5%.0 %(Foobar;.*") == uas)
		end)
	end)
end