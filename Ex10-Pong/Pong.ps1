Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;

public class PongForm : Form
{
    private PictureBox ball;
    private Button leftPaddle, rightPaddle;
    private Timer timer;
    private int dx = 5, dy = 5;

    public PongForm()
    {
        // Setup form
        this.Size = new Size(800, 400);
        this.FormBorderStyle = FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        this.KeyPreview = true;
        this.KeyDown += HandleKeyPress;

        // Initialize ball
        ball = new PictureBox
        {
            Size = new Size(20, 20),
            Location = new Point(this.ClientSize.Width / 2, this.ClientSize.Height / 2),
            BackColor = Color.Red
        };
        this.Controls.Add(ball);

        // Initialize left paddle
        leftPaddle = new Button
        {
            Size = new Size(20, 80),
            Location = new Point(0, this.ClientSize.Height / 2)
        };
        this.Controls.Add(leftPaddle);

        // Initialize right paddle
        rightPaddle = new Button
        {
            Size = new Size(20, 80),
            Location = new Point(this.ClientSize.Width - 20, this.ClientSize.Height / 2)
        };
        this.Controls.Add(rightPaddle);

        // Initialize timer for game loop
        timer = new Timer();
        timer.Interval = 50; // change this for speed of game
        timer.Tick += Tick;
        timer.Start();
    }

    private void HandleKeyPress(object sender, KeyEventArgs e)
    {
        const int paddleSpeed = 20;

        switch (e.KeyCode)
        {
            case Keys.W:
                leftPaddle.Top = Math.Max(0, leftPaddle.Top - paddleSpeed);
                break;
            case Keys.S:
                leftPaddle.Top = Math.Min(this.ClientSize.Height - leftPaddle.Height, leftPaddle.Top + paddleSpeed);
                break;
            case Keys.Up:
                rightPaddle.Top = Math.Max(0, rightPaddle.Top - paddleSpeed);
                break;
            case Keys.Down:
                rightPaddle.Top = Math.Min(this.ClientSize.Height - rightPaddle.Height, rightPaddle.Top + paddleSpeed);
                break;
        }
    }

    private void Tick(object sender, EventArgs e)
    {
        // Move ball
        ball.Location = new Point(ball.Location.X + dx, ball.Location.Y + dy);

        // Check collision with walls
        if (ball.Location.Y <= 0 || ball.Location.Y >= this.ClientSize.Height - ball.Height)
            dy *= -1;

        // Check collision with paddles
        if (ball.Bounds.IntersectsWith(leftPaddle.Bounds) || ball.Bounds.IntersectsWith(rightPaddle.Bounds))
            dx *= -1;
    }
}
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

$form = New-Object PongForm
$form.ShowDialog()
