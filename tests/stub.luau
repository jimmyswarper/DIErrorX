-- Assertion helpers shared by every suite.

TESTS_RUN = 0
TESTS_FAILED = 0

function check(label, condition, detail)
	TESTS_RUN = TESTS_RUN + 1
	if not condition then
		TESTS_FAILED = TESTS_FAILED + 1
		print("  FAIL  " .. label .. (detail and ("\n        " .. tostring(detail)) or ""))
	end
end

function eq(label, got, want)
	TESTS_RUN = TESTS_RUN + 1
	if got ~= want then
		TESTS_FAILED = TESTS_FAILED + 1
		print("  FAIL  " .. label)
		print("        want: " .. string.gsub(tostring(want), "\n", "\n              "))
		print("        got:  " .. string.gsub(tostring(got), "\n", "\n              "))
	end
end

function report(suite)
	if TESTS_FAILED == 0 then
		print(string.format("  ok    %s (%d checks)", suite, TESTS_RUN))
	else
		print(string.format("  FAILED %s: %d of %d checks failed",
			suite, TESTS_FAILED, TESTS_RUN))
	end
end
