[void](Wait-For 'reader inspected the terminal input box' { (Read-Shared "$state/terminal-drafts.jsonl").Contains('"draft"') } 30)
$observation.replies = @(
    '^[[?61;1;6;7;21;22;23;24;28;32;42;52c^[[>0;10;1c',
    "$([char]27)[?61;1;6c$([char]27)[>0;10;1c",
    '^[[12;40R',
    "$([char]27)]10;rgb:1/1/1$([char]7)",
    '^[]10;rgb:1/1/1^G'
)
$observation.samples = @()
foreach ($reply in $observation.replies) {
    Shell-Input 'key' 'C-u'
    $offset = (Read-Shared "$state/terminal-drafts.jsonl").Length
    Shell-Input 'text' $reply
    [void](Wait-For 'production reader removed the complete terminal reply' {
        $rows = (Read-Shared "$state/terminal-drafts.jsonl").Substring($offset).Trim() -split "`n" | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
        @($rows | Where-Object { $_.screen.Contains($reply) -and $_.draft -ceq '' }).Count -gt 0
    } 20)
    $text = [ChatDeliveryDesktop]::Text($composer)
    $observation.samples += @{reply=$reply; composer=$text}
    if ($text -cne '') { throw "Terminal reply filled the message box: $text" }
}
Shot 'terminal-replies-empty'
Shell-Input 'key' 'C-u'
$offset = (Read-Shared "$state/terminal-drafts.jsonl").Length
Shell-Input 'text' '[]'
[void](Wait-For 'production reader preserved literal brackets' {
    $rows = (Read-Shared "$state/terminal-drafts.jsonl").Substring($offset).Trim() -split "`n" | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
    @($rows | Where-Object { $_.screen.Contains('❯ []') -and $_.draft -ceq '[]' }).Count -gt 0
} 20)
Shell-Input 'key' 'C-u'
Type-Composer '[]'
$observation.typed = [ChatDeliveryDesktop]::Text($composer)
if ($observation.typed -cne '[]') { throw 'Typed brackets were changed' }
Shot 'terminal-replies-typed'
$observation.endMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
