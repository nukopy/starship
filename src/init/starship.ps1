#!/usr/bin/env pwsh

function global:prompt {
    $origDollarQuestion = $global:?
    $origLastExitCode = $global:LASTEXITCODE

    $out = $null
    # @ makes sure the result is an array even if single or no values are returned
    $jobs = @(Get-Job | Where-Object { $_.State -eq 'Running' }).Count

    $env:PWD = $PWD
    $current_directory = (Convert-Path -LiteralPath $PWD)
    
    # If an external command has not been executed, then the $LASTEXITCODE will be $null.
    # For the purposes of the prompt, replace this with a 0 exit code so that the prompt
    # doesn't show the last command as a failure (because it had a non-zero exit code).
    $lastExitCodeForPrompt = if ($origLastExitCode) { $origLastExitCode } else { 0 }

    # Save old output encoding and set it to UTF-8
    $origOutputEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    if ($lastCmd = Get-History -Count 1) {
        $duration = [math]::Round(($lastCmd.EndExecutionTime - $lastCmd.StartExecutionTime).TotalMilliseconds)
        # & ensures the path is interpreted as something to execute
        $out = @(&::STARSHIP:: prompt "--path=$current_directory" --status=$lastExitCodeForPrompt --jobs=$jobs --cmd-duration=$duration)
    } else {
        $out = @(&::STARSHIP:: prompt "--path=$current_directory" --status=$lastExitCodeForPrompt --jobs=$jobs)
    }
    # Restore old output encoding
    [Console]::OutputEncoding = $origOutputEncoding

    # Convert stdout (array of lines) to expected return type string
    # `n is an escaped newline
    $out -join "`n"

    # Propagate the original $LASTEXITCODE from before the prompt function was invoked.
    $global:LASTEXITCODE = $origLastExitCode

    # Propagate the original $? automatic variable value from before the prompt function was invoked.
    #
    # $? is a read-only or constant variable so we can't directly override it.
    # In order to propagate up its original boolean value we will take an action
    # which will produce the desired value.
    #
    # This has to be the very last thing that happens in the prompt function
    # since every PowerShell command sets the $? variable.
    if ($global:? -ne $origDollarQuestion) {
        if ($origDollarQuestion) {
             # Simple command which will execute successfully and set $? = True without any other side affects.
            1+1
        } else {
            # Write-Error will set $? to False.
            # ErrorAction Ignore will prevent the error from being added to the $Error collection.
            Write-Error '' -ErrorAction 'Ignore'
        }
    }
}

$ENV:STARSHIP_SHELL = "powershell"

# Set up the session key that will be used to store logs
$ENV:STARSHIP_SESSION_KEY = (& ::STARSHIP:: session)
