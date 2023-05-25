$ball = @{'x' = 0; 'y' = 0; 'dx' = 1; 'dy' = 1}
$paddle = @{'y' = 0}

$consoleWidth = $host.UI.RawUI.WindowSize.Width
$consoleHeight = $host.UI.RawUI.WindowSize.Height

while ($true) {
    # Move the ball
    $ball.x += $ball.dx
    $ball.y += $ball.dy

    # Bounce off the walls
    if ($ball.x -lt 0 -or $ball.x -ge $consoleWidth) {
        $ball.dx *= -1
    }

    # Bounce off the paddle
    if ($ball.y -ge $consoleHeight - 2) {
        if ($ball.x -ge $paddle.y - 2 -and $ball.x -le $paddle.y + 2) {
            $ball.dy *= -1
        }
        else {
            break # End the game if the ball hits the bottom and isn't caught
        }
    }
    elseif ($ball.y -lt 0) {
        $ball.dy *= -1
    }

    # Move the paddle to follow the ball
    $paddle.y = $ball.x

    # Draw everything
    Clear-Host
    Write-Host "`n" * $ball.y + (" " * $ball.x + "O") # Ball
    Write-Host "`n" * ($consoleHeight - $ball.y - 3) # Space between the ball and the paddle
    Write-Host " " * ($paddle.y - 2) + "=====" # Paddle

    Start-Sleep -Milliseconds 100
}

Write-Host "Game Over!"
