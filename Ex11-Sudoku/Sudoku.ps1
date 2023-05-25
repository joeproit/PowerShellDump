function Show-SudokuBoard($board) {
    $horizontalSeparator = "+--+----+----+--+--+----+----+--+--+----+----+--+"

    for ($row = 0; $row -lt 9; $row++) {
        if ($row % 3 -eq 0) { Write-Host $horizontalSeparator }

        for ($col = 0; $col -lt 9; $col++) {
            if ($col % 3 -eq 0) { Write-Host -NoNewline "|" }

            Write-Host -NoNewline " " + $board[$row][$col]
        }

        Write-Host "|"
    }

    Write-Host $horizontalSeparator
}

function Set-SudokuValue($board, $row, $col, $value) {
    $board[$row-1][$col-1] = $value
}

$board = @( @(5,3,0,0,7,0,0,0,0),
             @(6,0,0,1,9,5,0,0,0),
             @(0,9,8,0,0,0,0,6,0),
             @(8,0,0,0,6,0,0,0,3),
             @(4,0,0,8,0,3,0,0,1),
             @(7,0,0,0,2,0,0,0,6),
             @(0,6,0,0,0,0,2,8,0),
             @(0,0,0,4,1,9,0,0,5),
             @(0,0,0,0,8,0,0,7,9))

while ($true) {
    Show-SudokuBoard $board
    $row = Read-Host "Enter row (1-9)"
    $col = Read-Host "Enter column (1-9)"
    $value = Read-Host "Enter value (1-9)"
    Set-SudokuValue $board $row $col $value
}
