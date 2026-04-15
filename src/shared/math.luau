--!strict
--!optimize 2
--[[
	Math V0.1.0

	Stores math functions that are only used in multiple files/functions,
	if something is used only in one place, it is inlined
]]
-----------------------------------------------------
-- LOCALIZATIONS                                   --
-----------------------------------------------------
const SQRT: (number) -> number = math.sqrt

-----------------------------------------------------
-- MATH FUNCTIONS                                  --
-----------------------------------------------------
@native
const function toQuaternion(cf: CFrame): (number, number, number, number)
	const _, _, _, m00: number, m01: number, m02: number, m10: number, m11: number, m12: number, m20: number, m21: number, m22: number =
		cf:GetComponents()

	const trace: number = m00 + m11 + m22
	local qx: number, qy: number, qz: number, qw: number

	if trace > 0 then
		const s = SQRT(trace + 1) * 2
		qw = 0.25 * s
		qx = (m21 - m12) / s
		qy = (m02 - m20) / s
		qz = (m10 - m01) / s
	elseif (m00 > m11) and (m00 > m22) then
		const s = SQRT(1 + m00 - m11 - m22) * 2
		qw = (m21 - m12) / s
		qx = 0.25 * s
		qy = (m01 + m10) / s
		qz = (m02 + m20) / s
	elseif m11 > m22 then
		const s = SQRT(1 + m11 - m00 - m22) * 2
		qw = (m02 - m20) / s
		qx = (m01 + m10) / s
		qy = 0.25 * s
		qz = (m12 + m21) / s
	else
		const s = SQRT(1 + m22 - m00 - m11) * 2
		qw = (m10 - m01) / s
		qx = (m02 + m20) / s
		qy = (m12 + m21) / s
		qz = 0.25 * s
	end

	return qx, qy, qz, qw
end
return table.freeze({
	toQuaternion = toQuaternion,
})