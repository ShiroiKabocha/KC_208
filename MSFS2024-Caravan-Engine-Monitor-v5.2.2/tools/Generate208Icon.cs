using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;

internal static class Generate208Icon
{
    private static readonly int[] Sizes = { 16, 20, 24, 32, 48, 64, 128, 256 };

    public static void Main(string[] args)
    {
        string output = args.Length > 0 ? args[0] : "Kabocha208.ico";
        byte[][] images = new byte[Sizes.Length][];
        for (int i = 0; i < Sizes.Length; i++) images[i] = RenderDib(Sizes[i]);

        using (FileStream file = File.Create(output))
        using (BinaryWriter writer = new BinaryWriter(file))
        {
            writer.Write((ushort)0);
            writer.Write((ushort)1);
            writer.Write((ushort)Sizes.Length);
            int offset = 6 + Sizes.Length * 16;
            for (int i = 0; i < Sizes.Length; i++)
            {
                int size = Sizes[i];
                writer.Write((byte)(size == 256 ? 0 : size));
                writer.Write((byte)(size == 256 ? 0 : size));
                writer.Write((byte)0);
                writer.Write((byte)0);
                writer.Write((ushort)1);
                writer.Write((ushort)32);
                writer.Write((uint)images[i].Length);
                writer.Write((uint)offset);
                offset += images[i].Length;
            }
            for (int i = 0; i < images.Length; i++) writer.Write(images[i]);
        }
    }

    private static byte[] RenderDib(int size)
    {
        using (Bitmap bitmap = new Bitmap(size, size, System.Drawing.Imaging.PixelFormat.Format32bppArgb))
        using (Graphics graphics = Graphics.FromImage(bitmap))
        using (MemoryStream stream = new MemoryStream())
        using (BinaryWriter writer = new BinaryWriter(stream))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            graphics.Clear(Color.Transparent);

            float inset = Math.Max(1f, size * 0.055f);
            float radius = Math.Max(2f, size * 0.15f);
            RectangleF face = new RectangleF(inset, inset, size - inset * 2f, size - inset * 2f);
            using (GraphicsPath path = RoundedRectangle(face, radius))
            using (LinearGradientBrush fill = new LinearGradientBrush(face, Color.FromArgb(255, 27, 30, 32), Color.FromArgb(255, 4, 5, 6), 90f))
            using (Pen edge = new Pen(Color.FromArgb(255, 91, 96, 98), Math.Max(1f, size * 0.035f)))
            {
                graphics.FillPath(fill, path);
                graphics.DrawPath(edge, path);
            }

            float fontSize = size * 0.43f;
            using (Font font = new Font("Arial Narrow", fontSize, FontStyle.Bold, GraphicsUnit.Pixel))
            using (StringFormat format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
            using (Brush shadow = new SolidBrush(Color.FromArgb(210, 0, 0, 0)))
            using (Brush text = new SolidBrush(Color.FromArgb(255, 230, 226, 207)))
            {
                RectangleF textBox = new RectangleF(0, size * 0.03f, size, size * 0.94f);
                RectangleF shadowBox = textBox; shadowBox.X += Math.Max(1f, size * 0.018f); shadowBox.Y += Math.Max(1f, size * 0.025f);
                graphics.DrawString("208", font, shadow, shadowBox, format);
                graphics.DrawString("208", font, text, textBox, format);
            }

            int xorBytes = size * size * 4;
            int maskStride = ((size + 31) / 32) * 4;
            writer.Write((uint)40);
            writer.Write((int)size);
            writer.Write((int)(size * 2));
            writer.Write((ushort)1);
            writer.Write((ushort)32);
            writer.Write((uint)0);
            writer.Write((uint)xorBytes);
            writer.Write((int)0);
            writer.Write((int)0);
            writer.Write((uint)0);
            writer.Write((uint)0);
            for (int y = size - 1; y >= 0; y--)
            {
                for (int x = 0; x < size; x++)
                {
                    Color pixel = bitmap.GetPixel(x, y);
                    writer.Write(pixel.B);
                    writer.Write(pixel.G);
                    writer.Write(pixel.R);
                    writer.Write(pixel.A);
                }
            }
            writer.Write(new byte[maskStride * size]);
            writer.Flush();
            return stream.ToArray();
        }
    }

    private static GraphicsPath RoundedRectangle(RectangleF rectangle, float radius)
    {
        float diameter = radius * 2f;
        GraphicsPath path = new GraphicsPath();
        path.AddArc(rectangle.Left, rectangle.Top, diameter, diameter, 180, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Top, diameter, diameter, 270, 90);
        path.AddArc(rectangle.Right - diameter, rectangle.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rectangle.Left, rectangle.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}
