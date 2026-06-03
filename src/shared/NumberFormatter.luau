-- NumberFormatter
-- Converts large numbers into readable abbreviated strings (e.g. 1500000 → "1.50M")
-- Usage:
--   local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
--   NumberFormatter.format(1234567)      --> "1.23M"
--   NumberFormatter.formatCommas(123456) --> "123,456"

local NumberFormatter = {}

-- Suffixes sorted from largest to smallest threshold.
-- Covers up to Vigintillion (10^63), well beyond Lua's double precision limit (~1.8 × 10^308).
local SUFFIXES: { { threshold: number, suffix: string } } = {
	{ threshold = 1e63, suffix = "Vg" },
	{ threshold = 1e60, suffix = "Nvg" },
	{ threshold = 1e57, suffix = "Ocg" },
	{ threshold = 1e54, suffix = "Spg" },
	{ threshold = 1e51, suffix = "Sxg" },
	{ threshold = 1e48, suffix = "Qig" },
	{ threshold = 1e45, suffix = "Qag" },
	{ threshold = 1e42, suffix = "Tg" },
	{ threshold = 1e39, suffix = "Dug" },
	{ threshold = 1e36, suffix = "Udg" },
	{ threshold = 1e33, suffix = "Dct" },
	{ threshold = 1e30, suffix = "No" },
	{ threshold = 1e27, suffix = "Oc" },
	{ threshold = 1e24, suffix = "Sp" },
	{ threshold = 1e21, suffix = "Sx" },
	{ threshold = 1e18, suffix = "Qi" },
	{ threshold = 1e15, suffix = "Qa" },
	{ threshold = 1e12, suffix = "T" },
	{ threshold = 1e9, suffix = "B" },
	{ threshold = 1e6, suffix = "M" },
	{ threshold = 1e3, suffix = "K" },
}

--- Inserts thousand-separator commas into an integer string.
-- e.g. "1234567" → "1,234,567"
local function addCommasToIntString(str: string): string
	local result = ""
	local len = #str
	for i = 1, len do
		result = result .. str:sub(i, i)
		local remaining = len - i
		if remaining > 0 and remaining % 3 == 0 then
			result = result .. ","
		end
	end
	return result
end

--- Formats a number with thousand-separator commas.
-- Numbers below 1,000 are returned as plain integers.
-- e.g. 1234567 → "1,234,567"  |  999 → "999"
function NumberFormatter.formatCommas(amount: number): string
	if amount ~= amount then
		return "NaN"
	end
	if amount == math.huge then
		return "∞"
	end
	if amount == -math.huge then
		return "-∞"
	end

	local negative = amount < 0
	amount = math.floor(math.abs(amount))

	local intStr = tostring(amount)
	local formatted = addCommasToIntString(intStr)

	return if negative then "-" .. formatted else formatted
end

--- Abbreviates a large number into a short suffixed string.
-- e.g. 1234    → "1.23K"
--      1500000 → "1.50M"
--      999     → "999"
--      -2.5e6  → "-2.50M"
function NumberFormatter.format(amount: number): string
	if amount ~= amount then
		return "NaN"
	end
	if amount == math.huge then
		return "∞"
	end
	if amount == -math.huge then
		return "-∞"
	end

	local negative = amount < 0
	amount = math.floor(math.abs(amount))

	-- Early exit for numbers below 1,000 — no need to iterate suffixes
	if amount < 1000 then
		return if negative then "-" .. tostring(amount) else tostring(amount)
	end

	for _, entry in ipairs(SUFFIXES) do
		if amount >= entry.threshold then
			local result = string.format("%.2f", amount / entry.threshold) .. entry.suffix
			return if negative then "-" .. result else result
		end
	end

	warn("NumberFormatter: No suffix found for " .. amount .. " (amount). This should not happen.")
	return tostring(amount)
end

return NumberFormatter
