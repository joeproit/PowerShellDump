Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;

public class SphereForm : Form {
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        Brush brush = new System.Drawing.Drawing2D.LinearGradientBrush(ClientRectangle, Color.Red, Color.Blue, 45);
        g.FillEllipse(brush, new RectangleF(50, 50, 200, 200));
        brush.Dispose();
    }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

$form = New-Object SphereForm
$form.ShowDialog()
