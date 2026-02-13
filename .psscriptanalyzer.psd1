@{
    # Use default rule set
    IncludeDefaultRules = $true

    # Only block on Errors (Warnings still visible in CI output)
    Severity = @('Error','Warning')

    # Exclude known noisy / non-runtime paths
    ExcludePaths = @(
        'DEV-Only',
        'Tools/_local',
        '_internal/_patch_backups',
        'Docs/_local',
        '.git'
    )

    # Optional: You can disable specific rules later like this:
    # ExcludeRules = @(
    #     'PSAvoidUsingWriteHost'
    # )
}
