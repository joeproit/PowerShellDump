Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Drawing.Drawing2D;

public class SphereForm : Form
{
    private Timer timer;
    private float angle = 0;

    public SphereForm()
    {
        this.DoubleBuffered = true;
        timer = new Timer();
        timer.Interval = 100; // change this for speed of rotation
        timer.Tick += (sender, e) => { this.angle += 5; this.Invalidate(); };
        timer.Start();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        LinearGradientBrush brush = new LinearGradientBrush(ClientRectangle, Color.Blue, Color.Red, angle);
        g.FillEllipse(brush, new RectangleF(50, 50, 200, 200));
        brush.Dispose();
    }
}
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

$form = New-Object SphereForm
$form.ShowDialog()
