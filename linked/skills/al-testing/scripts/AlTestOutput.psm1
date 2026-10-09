function Protect-AlTestOutput {
    param([string]$Text)
    $Text = $Text -replace '(?i)\bBearer\s+[^\s"'',;]+', 'Bearer [REDACTED]'
    $Text = $Text -replace '\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b', '[REDACTED JWT]'
    return ($Text -replace '(?i)(\b(?:access_token|refresh_token|client_secret|tokenHash)\b["'']?\s*[:=]\s*["'']?)[^\s"'',;]+', '$1[REDACTED]')
}

function Get-AlSaaSTestSummary {
    [CmdletBinding()]
    param([string[]]$Output, [bool]$Succeeded)

    $results = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $names = [System.Collections.Generic.HashSet[string]]::new()
    $conflicts = [System.Collections.Generic.HashSet[string]]::new()
    $totals = [System.Collections.Generic.HashSet[string]]::new()
    $headers = [System.Collections.Generic.HashSet[string]]::new()
    $unnamed = 0
    $unnamedFailed = 0
    $current = $null
    $inStack = $false
    $codeunit = ''
    foreach ($line in $Output) {
        if ($line -match '===== Codeunit (\d+) =====') {
            $codeunit = $Matches[1]
            [void]$headers.Add("===== Codeunit $codeunit =====")
            $current = $null
        }
        elseif ($line -match '^Test run completed:') {
            [void]$totals.Add($line.Trim())
            $current = $null
        }
        elseif ($line -match '^\s*(PASS|FAIL|SKIP)\s+(.*?)\s*(?:\((\d+)ms\))?\s*$') {
            $outcome = $Matches[1]
            $name = $Matches[2].Trim()
            $current = $null
            $inStack = $false
            if (-not $name) {
                $unnamed++
                if ($outcome -eq 'FAIL') { $unnamedFailed++ }
                continue
            }
            $key = "$codeunit|$name|$outcome"
            if (-not $seen.Add($key)) { continue }
            if (-not $names.Add("$codeunit|$name")) { [void]$conflicts.Add("$codeunit/$name") }
            $result = [pscustomobject]@{
                Name = $name; Outcome = $outcome; Display = $line.Trim()
                Errors = [System.Collections.Generic.List[string]]::new()
                Stack = [System.Collections.Generic.List[string]]::new()
            }
            $results.Add($result)
            if ($outcome -eq 'FAIL') { $current = $result }
        }
        elseif ($current -and $line -match '^\s*AL Call\s*stack:') {
            $inStack = $true
        }
        elseif ($current -and -not [string]::IsNullOrWhiteSpace($line) -and
            $line -notmatch '^\s*(\[MSAL\]|\[LogMetricsFromAuthResult\]|System\.Management\.Automation\.|Results:)') {
            $text = Protect-AlTestOutput -Text $line.Trim()
            if ($inStack) {
                if ($current.Stack.Count -lt 5) { $current.Stack.Add($text) }
            }
            elseif ($current.Errors.Count -lt 6) { $current.Errors.Add($text) }
        }
    }

    foreach ($header in $headers) { $header }
    foreach ($result in $results) {
        Protect-AlTestOutput -Text $result.Display
        if ($result.Outcome -eq 'FAIL') {
            foreach ($errorLine in $result.Errors) { "  Error: $errorLine" }
            foreach ($frame in $result.Stack) { "  AL stack: $frame" }
            if ($result.Errors.Count -eq 0 -and $result.Stack.Count -eq 0) {
                '  No failure details in runner output; inspect the full log.'
            }
        }
    }
    $passed = @($results | Where-Object Outcome -eq 'PASS').Count
    $failed = @($results | Where-Object Outcome -eq 'FAIL').Count
    $skipped = @($results | Where-Object Outcome -eq 'SKIP').Count
    if ($unnamedFailed -gt 0) { "Unnamed runner FAIL records: $unnamedFailed (not named tests); inspect the full log for their details." }
    if ($results.Count -gt 0 -or $unnamed -gt 0) {
        if ($conflicts.Count -gt 0) {
            "WARNING: conflicting outcomes for named tests: $($conflicts -join ', '). Counts below are result records, not unique tests."
            "Named result records: $passed passed, $failed failed, $skipped skipped. Unnamed runner records: $unnamed."
        }
        else {
            "Named tests: $passed passed, $failed failed, $skipped skipped. Unnamed runner records: $unnamed (not counted as tests)."
        }
    }
    foreach ($total in $totals) { "Runner aggregate: $total" }
    if ($totals.Count -gt 1) { 'WARNING: runner reported different aggregates; inspect the full log.' }
    if (-not $Succeeded -and $failed -eq 0) {
        'Runner/process failed without a named failing test. Relevant output:'
        $Output | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and
            $_ -notmatch '^\s*(\[MSAL\]|\[LogMetricsFromAuthResult\]|Using VS Code authentication|System\.Management\.Automation\.)'
        } | Select-Object -Last 12 | ForEach-Object { Protect-AlTestOutput -Text $_ }
    }
}

Export-ModuleMember -Function Get-AlSaaSTestSummary
