--!strict
--!optimize 2
--[[
	VoidSentry2 fail function.
	Respects runtime strictMode: errors when true, warns when false.
]]
export type FailFn = (<T...>(T...) -> ()) | (<T>(T, number?) -> never)

return @native function(config: { strictMode: boolean }): FailFn
	@native
	const function failFn(message: string, level: number?)
		if config.strictMode then
			error(message, level)
		else
			warn(message)
		end
	end
	return failFn :: FailFn
end
