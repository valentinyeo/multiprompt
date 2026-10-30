$selection = '[palette] ready chars=20 count=2 target=6364'
$menu = '[palette] ready chars=9 count=2 target=6466'
$checks = @(
    @{log=$selection; length=20; target=6364; expected=$true},
    @{log=$menu; length=9; target=6466; expected=$true},
    @{log='[palette] ready chars=20 count=0 target=6364'; length=20; target=6364; expected=$false},
    @{log='[palette] ready chars=20 count=2 target=6466'; length=20; target=6364; expected=$false},
    @{log='[palette] ready chars=20 count=2 target=63640'; length=20; target=6364; expected=$false},
    @{log='[palette] ready chars=19 count=2 target=6364'; length=20; target=6364; expected=$false},
    @{log=($selection + "`n" + '[palette] ready chars=20 count=2 target=6466'); length=20; target=6364; expected=$false}
)
foreach ($check in $checks) {
    if ((Test-RecoveryPaletteSelection $check.log $check.length $check.target) -ne $check.expected) {
        throw "Recovery palette predicate failed control: $($check.log)"
    }
}
