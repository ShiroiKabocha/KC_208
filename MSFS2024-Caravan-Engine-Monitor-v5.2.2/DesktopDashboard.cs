using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

internal sealed class DashboardData
{
    internal bool Connected, OnGround, Starter, StarterActive, BatteryMaster, EngineCovers, InertialSeparator, AircraftCompatible;
    internal double Itt, Heading, HeadingBug, Course, Torque, Ng, FuelPressure, PropRpm, FuelFlow, OilPressure, OilTemperature, Oat;
    internal double Agl, PressureAltitude, VerticalSpeed, FuelSelector, LeftFuelQuantity, RightFuelQuantity, FuelWeightPerGallon;
    internal double FuelCutoffHandle, FirewallCutoffHandle, BusVoltage, FuelPumpSwitch, ConditionLever, PropLeverPosition, PowerLeverPosition;
    internal string TailNumber, AircraftTitle, Message;
    internal DateTime UpdatedUtc;
}

internal sealed class DesktopDashboard : Form
{
    private static readonly Color Chassis = Color.FromArgb(8, 9, 10);
    private static readonly Color Module = Color.FromArgb(20, 23, 26);
    private static readonly Color Edge = Color.FromArgb(64, 68, 70);
    private static readonly Color OffWhite = Color.FromArgb(221, 217, 203);
    private static readonly Color Green = Color.FromArgb(143, 207, 118);
    private static readonly Color Amber = Color.FromArgb(239, 184, 78);
    private static readonly Color Red = Color.FromArgb(240, 90, 79);
    private static readonly Color Lcd = Color.FromArgb(239, 84, 47);

    private readonly Timer timer = new Timer();
    private readonly Timer powerHold = new Timer();
    private readonly Dictionary<string, RailItem> rails = new Dictionary<string, RailItem>();
    private readonly Dictionary<string, InstrumentCard> cards = new Dictionary<string, InstrumentCard>();
    private readonly Dictionary<string, bool> preLatch = new Dictionary<string, bool>();
    private readonly Dictionary<string, string> preLatchValue = new Dictionary<string, string>();
    private readonly List<string> events = new List<string>();
    private readonly Dictionary<string, bool> activeCritical = new Dictionary<string, bool>();
    private readonly Label tail = new Label(), advisoryTitle = new Label(), advisoryLines = new Label(), connection = new Label(), logCount = new Label();
    private readonly ListBox eventLog = new ListBox();
    private readonly NotifyIcon tray = new NotifyIcon();
    private bool allowExit, startCycle, startComplete, cruise;
    private DateTime? cruiseCandidate, cruiseExit, starterBegan, propOverBegan, propTransientBegan, oilBaselineBegan, shutdownBegan;
    private double oilBaseline = -1, oilPeak;

    internal DesktopDashboard()
    {
        Text = "208 EICAS";
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        BackColor = Color.FromArgb(13, 15, 16);
        ForeColor = OffWhite;
        MinimumSize = new Size(1180, 720);
        Size = new Size(1540, 900);
        StartPosition = FormStartPosition.CenterScreen;
        BuildInterface();
        BuildTray();
        timer.Interval = 100;
        timer.Tick += delegate { Render(Program.GetDashboardData()); };
        timer.Start();
        FormClosing += OnFormClosing;
    }

    private void BuildInterface()
    {
        Panel face = new Panel { Dock = DockStyle.Fill, BackColor = Chassis, Padding = new Padding(14) };
        Controls.Add(face);
        TableLayoutPanel frame = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1, BackColor = Chassis };
        frame.RowStyles.Add(new RowStyle(SizeType.Absolute, 52)); frame.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); face.Controls.Add(frame);

        TableLayoutPanel header = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 4, BackColor = Chassis, Padding = new Padding(5, 3, 5, 7) };
        header.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize)); header.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 170)); header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); header.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 100));
        Label brand = NewLabel("Kabocha 208 EICAS", 18, FontStyle.Bold, OffWhite); brand.AutoSize = true; brand.Margin = new Padding(0, 8, 22, 0); header.Controls.Add(brand, 0, 0);
        tail.Text = "--------"; tail.Font = new Font("Consolas", 16, FontStyle.Bold); tail.TextAlign = ContentAlignment.MiddleCenter; tail.ForeColor = Green; tail.BackColor = Color.FromArgb(5, 18, 8); tail.Dock = DockStyle.Fill; tail.Margin = new Padding(0, 3, 0, 3); header.Controls.Add(tail, 1, 0);
        Button power = NewButton("PWR"); power.Anchor = AnchorStyles.Right; powerHold.Interval = 1200; powerHold.Tick += delegate { powerHold.Stop(); ExitApplication(); }; power.MouseDown += delegate { power.BackColor = Color.FromArgb(65, 78, 62); powerHold.Start(); }; power.MouseUp += delegate { powerHold.Stop(); power.BackColor = Color.FromArgb(38, 42, 44); }; power.MouseLeave += delegate { powerHold.Stop(); power.BackColor = Color.FromArgb(38, 42, 44); }; header.Controls.Add(power, 2, 0);
        connection.Text = "INOP"; connection.Font = new Font("Arial Narrow", 9, FontStyle.Bold); connection.TextAlign = ContentAlignment.MiddleCenter; connection.Dock = DockStyle.Fill; connection.Margin = new Padding(20, 7, 5, 7); header.Controls.Add(connection, 3, 0);
        frame.Controls.Add(header, 0, 0);

        TableLayoutPanel body = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, BackColor = Chassis };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 420)); body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100)); body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 265));
        body.Controls.Add(BuildRails(), 0, 0); body.Controls.Add(BuildMonitors(), 1, 0); body.Controls.Add(BuildLog(), 2, 0); frame.Controls.Add(body, 0, 1);
    }

    private Control BuildRails()
    {
        TableLayoutPanel bank = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 2, BackColor = Chassis, Padding = new Padding(0, 0, 10, 0) };
        bank.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50)); bank.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50)); bank.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); bank.RowStyles.Add(new RowStyle(SizeType.Absolute, 56));
        Panel pre = NewRack("PRE-START CHECKS"); AddRail(pre, "covers", "ENGINE COVERS"); AddRail(pre, "left", "LEFT FUEL"); AddRail(pre, "right", "RIGHT FUEL"); AddRail(pre, "fuelcutoff", "FUEL CUTOFF"); AddRail(pre, "firewall", "FIREWALL VALVE"); AddRail(pre, "prop", "PROPELLER LEVER"); AddRail(pre, "power", "POWER LEVER"); AddRail(pre, "inertial", "INERTIAL SEPARATOR"); bank.Controls.Add(pre, 0, 0);
        TableLayoutPanel right = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, BackColor = Chassis }; right.RowStyles.Add(new RowStyle(SizeType.Percent, 46)); right.RowStyles.Add(new RowStyle(SizeType.Percent, 54));
        Panel setup = NewRack("START SETUP"); AddRail(setup, "condition", "CONDITION LEVER"); AddRail(setup, "battery", "BATTERY / BUS"); AddRail(setup, "pump", "BOOST PUMP"); AddRail(setup, "starter", "STARTER"); right.Controls.Add(setup, 0, 0);
        Panel sequence = NewRack("START SEQUENCE"); AddRail(sequence, "seqcondition", "CONDITION LEVER"); AddRail(sequence, "seqstarter", "STARTER"); AddRail(sequence, "seqpump", "BOOST PUMP"); AddRail(sequence, "ready", "AIRCRAFT STATUS"); right.Controls.Add(sequence, 0, 1); bank.Controls.Add(right, 1, 0);
        FlowLayoutPanel dim = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.LeftToRight, BackColor = Chassis, Padding = new Padding(8, 8, 0, 0) };
        dim.Controls.Add(NewLabel("DIM", 8, FontStyle.Bold, Color.Gray)); TrackBar brightness = new TrackBar { Minimum = 25, Maximum = 100, Value = 100, Width = 115, TickStyle = TickStyle.None }; brightness.ValueChanged += delegate { SetBrightness(brightness.Value); }; dim.Controls.Add(brightness); dim.Controls.Add(NewLabel("BRT", 8, FontStyle.Bold, Color.Gray)); bank.Controls.Add(dim, 0, 1); bank.SetColumnSpan(dim, 2); return bank;
    }

    private Control BuildMonitors()
    {
        TableLayoutPanel area = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 5, BackColor = Chassis, Padding = new Padding(0, 0, 10, 0) };
        area.RowStyles.Add(new RowStyle(SizeType.Absolute, 19)); area.RowStyles.Add(new RowStyle(SizeType.Absolute, 64)); area.RowStyles.Add(new RowStyle(SizeType.Percent, 53)); area.RowStyles.Add(new RowStyle(SizeType.Percent, 31)); area.RowStyles.Add(new RowStyle(SizeType.Percent, 16));
        area.Controls.Add(NewSection("ADVISORIES"), 0, 0);
        Panel advisory = new Panel { Dock = DockStyle.Fill, BackColor = Color.FromArgb(15, 18, 15), BorderStyle = BorderStyle.Fixed3D, Padding = new Padding(10, 7, 10, 4) };
        advisoryTitle.Text = "ENGINE PARAMETERS NORMAL"; advisoryTitle.Font = new Font("Consolas", 11, FontStyle.Bold); advisoryTitle.ForeColor = Green; advisoryTitle.Dock = DockStyle.Top; advisoryTitle.Height = 22; advisory.Controls.Add(advisoryTitle);
        advisoryLines.Font = new Font("Consolas", 8); advisoryLines.ForeColor = OffWhite; advisoryLines.Dock = DockStyle.Fill; advisory.Controls.Add(advisoryLines); area.Controls.Add(advisory, 0, 1);
        TableLayoutPanel primary = NewCardGrid(); AddCard(primary, "itt", "ITT", "DEG C"); AddCard(primary, "torque", "TORQUE", "FT-LB"); AddCard(primary, "ng", "GAS GENERATOR", "% NG"); AddCard(primary, "propRpm", "PROPELLER", "RPM"); AddCard(primary, "oilPressure", "OIL PRESSURE", "PSI"); AddCard(primary, "oilTemperature", "OIL TEMPERATURE", "DEG C"); AddCard(primary, "fuelPressure", "FUEL PRESSURE", "PSI"); AddCard(primary, "fuelFlow", "FUEL FLOW", "PPH"); area.Controls.Add(primary, 0, 2);
        TableLayoutPanel nav = NewNavGrid(); AddCard(nav, "heading", "MAGNETIC HEADING", ""); AddCard(nav, "headingBug", "HEADING BUG", ""); AddCard(nav, "course", "SELECTED COURSE", ""); AddCard(nav, "oat", "OUTSIDE AIR", "DEG C"); AddCard(nav, "fuelFlowRaw", "FUEL FLOW RAW", "APPROX GPH"); area.Controls.Add(nav, 0, 3);
        return area;
    }

    private Control BuildLog()
    {
        TableLayoutPanel host = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, BackColor = Chassis, Padding = new Padding(0, 0, 0, 0) };
        host.RowStyles.Add(new RowStyle(SizeType.Absolute, 34)); host.RowStyles.Add(new RowStyle(SizeType.Absolute, 25)); host.RowStyles.Add(new RowStyle(SizeType.Absolute, 25)); host.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        Button clear = NewButton("CLR LAST"); clear.Click += delegate { if (events.Count > 0) { events.RemoveAt(events.Count - 1); RefreshLog(); } }; host.Controls.Add(clear, 0, 0);
        host.Controls.Add(NewSection("CRITICAL ADVISORY LOG"), 0, 1); logCount.Text = "00 EVENTS"; logCount.ForeColor = Green; logCount.Font = new Font("Consolas", 8); logCount.Dock = DockStyle.Fill; logCount.TextAlign = ContentAlignment.MiddleRight; host.Controls.Add(logCount, 0, 2);
        eventLog.BackColor = Color.FromArgb(4, 14, 8); eventLog.ForeColor = Green; eventLog.BorderStyle = BorderStyle.Fixed3D; eventLog.Font = new Font("Consolas", 8); eventLog.Dock = DockStyle.Fill; eventLog.HorizontalScrollbar = true; host.Controls.Add(eventLog, 0, 3); return host;
    }

    private Panel NewRack(string title)
    {
        Panel p = new Panel { Dock = DockStyle.Fill, BackColor = Module, BorderStyle = BorderStyle.FixedSingle, Padding = new Padding(6, 27, 6, 5), Margin = new Padding(0, 0, 7, 7) };
        Label l = NewLabel(title, 9, FontStyle.Bold, OffWhite); l.Dock = DockStyle.Top; l.Height = 23; l.Location = new Point(7, 3); l.TextAlign = ContentAlignment.MiddleLeft; p.Controls.Add(l); l.BringToFront(); return p;
    }

    private void AddRail(Panel host, string key, string name)
    {
        RailItem item = new RailItem(name, Lcd, Green, Red, Amber); item.Dock = DockStyle.Top; item.Height = 54; host.Controls.Add(item); item.BringToFront(); rails[key] = item;
    }

    private static TableLayoutPanel NewCardGrid()
    {
        TableLayoutPanel p = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 4, RowCount = 2, BackColor = Module, Padding = new Padding(3), Margin = new Padding(0, 5, 0, 5), CellBorderStyle = TableLayoutPanelCellBorderStyle.Single };
        for (int i = 0; i < 4; i++) p.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 25)); p.RowStyles.Add(new RowStyle(SizeType.Percent, 50)); p.RowStyles.Add(new RowStyle(SizeType.Percent, 50)); return p;
    }

    private static TableLayoutPanel NewNavGrid()
    {
        TableLayoutPanel p = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 5, RowCount = 1, BackColor = Module, Padding = new Padding(3), Margin = new Padding(0, 5, 0, 5), CellBorderStyle = TableLayoutPanelCellBorderStyle.Single };
        for (int i = 0; i < 5; i++) p.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 20)); p.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); return p;
    }

    private void AddCard(TableLayoutPanel grid, string key, string name, string unit)
    {
        InstrumentCard c = new InstrumentCard(name, unit, Lcd, OffWhite); int n = grid.Controls.Count; grid.Controls.Add(c, n % 4, n / 4); cards[key] = c;
    }

    private static Label NewLabel(string text, float size, FontStyle style, Color color) { return new Label { Text = text, Font = new Font("Arial Narrow", size, style), ForeColor = color, BackColor = Color.Transparent, AutoSize = true }; }
    private static Label NewSection(string text) { Label l = NewLabel(text, 9, FontStyle.Bold, Color.FromArgb(210, 205, 190)); l.Dock = DockStyle.Fill; l.TextAlign = ContentAlignment.BottomLeft; return l; }
    private static Button NewButton(string text) { return new Button { Text = text, Width = 72, Height = 25, FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(38, 42, 44), ForeColor = OffWhite, Font = new Font("Arial Narrow", 8, FontStyle.Bold) }; }

    private void BuildTray()
    {
        tray.Icon = Icon ?? SystemIcons.Application; tray.Text = "208 EICAS"; tray.Visible = true;
        ContextMenu menu = new ContextMenu(); menu.MenuItems.Add("Open Dashboard", delegate { Show(); WindowState = FormWindowState.Normal; Activate(); }); menu.MenuItems.Add("-"); menu.MenuItems.Add("Exit", delegate { ExitApplication(); }); tray.ContextMenu = menu;
        tray.DoubleClick += delegate { Show(); WindowState = FormWindowState.Normal; Activate(); };
    }

    private void OnFormClosing(object sender, FormClosingEventArgs e) { if (!allowExit && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); } }
    private void ExitApplication() { allowExit = true; timer.Stop(); powerHold.Stop(); tray.Visible = false; Program.BeginShutdown(); Close(); }

    private void Render(DashboardData d)
    {
        bool live = d.Connected && d.AircraftCompatible;
        connection.Text = live ? "●" : "INOP"; connection.ForeColor = live ? Green : Color.FromArgb(210, 195, 155); connection.BackColor = live ? Color.Transparent : Color.FromArgb(90, 75, 50);
        connection.Tag = d.Message; if (!live) return;
        tail.Text = String.IsNullOrWhiteSpace(d.TailNumber) ? "--------" : d.TailNumber.Trim();
        RenderRails(d); string phase = Phase(d); CruiseGuide guide = Guide(d.PressureAltitude, d.AircraftTitle);
        SetCard("itt", d.Itt, "0", phase == "CRUISE" ? "GUIDE <720 · LIMIT 740 C" : phase == "TAKEOFF" ? "MAX 805 C" : phase == "STARTING" ? "MAX 1090 C / 2 SEC" : "MAX 765 C", d.Itt / (phase == "STARTING" ? 1150 : 805) * 100);
        SetCard("torque", d.Torque, "0", phase == "CRUISE" ? "GUIDE " + guide.Torque + " · LIMIT 1865 FT-LB" : "MAX 1865 FT-LB", d.Torque / 2400 * 100);
        SetCard("ng", d.Ng, "0.0", phase == "CRUISE" ? "GUIDE <99 · LIMIT 101.6%" : "MAX 101.6%", d.Ng / 105 * 100);
        SetCard("propRpm", d.PropRpm, "0", phase == "CRUISE" ? "GUIDE 1750 · LIMIT 1900 RPM" : "MAX 1900 · 2090 / 2 SEC", d.PropRpm / 2200 * 100);
        SetCard("oilPressure", d.OilPressure, "0", oilBaseline > 0 ? "POST-START BASELINE " + oilBaseline.ToString("0") + " PSI" : "BASELINE CAPTURES AFTER 52% NG", d.OilPressure / 120 * 100);
        SetCard("oilTemperature", d.OilTemperature, "0", "99 CONTINUOUS / 104 TRANSIENT", d.OilTemperature / 110 * 100);
        SetCard("fuelPressure", d.FuelPressure, "0.0", "", d.FuelPressure / 30 * 100);
        SetCard("fuelFlow", d.FuelFlow, "0", phase == "CRUISE" ? "GUIDE " + guide.Fuel + " PPH · ISA · " + Math.Round(d.PressureAltitude) + " FT PA" : "", d.FuelFlow / 500 * 100);
        SetCard("heading", d.Heading * 3.6, "000°", "", d.Heading * 3.6 / 360 * 100); SetCard("headingBug", d.HeadingBug, "000°", "", d.HeadingBug / 360 * 100); SetCard("course", d.Course, "000°", "", d.Course / 360 * 100); SetCard("oat", d.Oat, "0", "", 0); SetCard("fuelFlowRaw", d.FuelFlow / 6.7, "0.0", "", d.FuelFlow / 500 * 100);
        Analyze(d, phase);
    }

    private void RenderRails(DashboardData d)
    {
        DateTime now = DateTime.UtcNow; int selector = (int)Math.Round(d.FuelSelector); bool left = selector == 1 || selector == 2, right = selector == 1 || selector == 3;
        bool cutoffIn = d.FuelCutoffHandle <= 80, firewallIn = d.FirewallCutoffHandle < 60; int pump = (int)Math.Round(d.FuelPumpSwitch), condition = (int)Math.Round(d.ConditionLever);
        if (d.StarterActive || d.Ng > 5) startCycle = true;
        SetPre("covers", !d.EngineCovers, d.EngineCovers ? "INSTALLED" : "REMOVED"); SetPre("left", left && d.LeftFuelQuantity > 1, left ? "OPEN" : "CLOSED"); SetPre("right", right && d.RightFuelQuantity > 1, right ? "OPEN" : "CLOSED");
        SetPre("fuelcutoff", cutoffIn, cutoffIn ? "PUSHED IN" : "PULLED OUT"); SetPre("firewall", firewallIn, firewallIn ? "PUSHED IN" : "PULLED OUT"); SetPre("prop", d.PropLeverPosition >= 95, d.PropLeverPosition.ToString("0") + "%"); SetPre("power", d.PowerLeverPosition >= 15 && d.PowerLeverPosition <= 35, d.PowerLeverPosition.ToString("0") + "%"); SetPre("inertial", d.InertialSeparator, d.InertialSeparator ? "OPEN" : "CLOSED");
        bool allPre = true; foreach (string k in new string[] { "covers", "left", "right", "fuelcutoff", "firewall", "prop", "power", "inertial" }) if (!preLatch.ContainsKey(k) || !preLatch[k]) allPre = false;
        SetRail("condition", condition == 0, condition == 0 ? "CUTOFF" : condition == 1 ? "LOW IDLE" : "HIGH IDLE", false);
        SetRail("battery", d.BatteryMaster && d.BusVoltage >= 24, (d.BatteryMaster ? "ON" : "OFF") + " · " + d.BusVoltage.ToString("0.0") + " V", false);
        SetRail("pump", pump == 0, pump == 0 ? "ON" : pump == 1 ? "NORM" : "OFF", false);
        bool starterReady = allPre && condition == 0 && d.BatteryMaster && d.BusVoltage >= 24 && pump == 0 && !d.StarterActive; SetRail("starter", starterReady || d.StarterActive, starterReady ? "ENGAGE" : d.StarterActive ? "MOTOR ON" : "WAIT", starterReady);
        bool moveLow = d.StarterActive && d.Ng >= 12 && condition == 0; SetRail("seqcondition", condition > 0, moveLow ? "MOVE TO LOW IDLE" : condition > 0 ? "LOW IDLE" : "WAIT", moveLow);
        bool starterOff = !d.StarterActive && d.Ng >= 52; SetRail("seqstarter", starterOff, d.Starter && starterOff ? "TURN OFF" : d.StarterActive ? "MOTOR ON" : starterOff ? "OFF" : "WAIT", d.Starter && starterOff);
        bool pumpDone = starterOff && pump == 1; SetRail("seqpump", pumpDone, starterOff && pump != 1 ? "SET TO NORMAL" : pump == 1 ? "NORM" : "WAIT", starterOff && pump != 1);
        startComplete = condition > 0 && starterOff && pumpDone && d.FuelFlow > 1; SetRail("ready", startComplete, startComplete ? "FLIGHT READY" : "NOT READY", false);
        bool stopped = startCycle && !d.StarterActive && d.Ng < 5 && d.FuelFlow < 1;
        if (stopped) { if (!shutdownBegan.HasValue) shutdownBegan = now; else if ((now - shutdownBegan.Value).TotalSeconds >= 3) ResetCycle(); } else shutdownBegan = null;
    }

    private void SetPre(string key, bool good, string value)
    {
        if (startCycle && good && (!preLatch.ContainsKey(key) || !preLatch[key])) { preLatch[key] = true; preLatchValue[key] = value; }
        bool latched = startCycle && preLatch.ContainsKey(key) && preLatch[key]; SetRail(key, good || latched, latched ? preLatchValue[key] : value, false);
    }
    private void SetRail(string key, bool good, string value, bool action) { if (rails.ContainsKey(key)) rails[key].SetState(good, action, value); }

    private string Phase(DashboardData d)
    {
        if (d.StarterActive || (d.Ng > 0 && d.Ng < 52 && d.FuelFlow > 0)) return "STARTING";
        if (d.OnGround) { cruise = false; cruiseCandidate = cruiseExit = null; return "TAKEOFF"; }
        DateTime now = DateTime.UtcNow; bool stable = Math.Abs(d.VerticalSpeed) <= 100;
        if (stable) { cruiseExit = null; if (!cruiseCandidate.HasValue) cruiseCandidate = now; if ((now - cruiseCandidate.Value).TotalSeconds >= 5) cruise = true; }
        else { cruiseCandidate = null; if (cruise) { if (!cruiseExit.HasValue) cruiseExit = now; if ((now - cruiseExit.Value).TotalSeconds >= 2) cruise = false; } }
        return cruise ? "CRUISE" : "CLIMB";
    }

    private void Analyze(DashboardData d, string phase)
    {
        DateTime now = DateTime.UtcNow; List<AlertItem> alerts = new List<AlertItem>();
        double ittWarning = phase == "TAKEOFF" ? 765 : 740, ittCritical = phase == "TAKEOFF" ? 805 : phase == "STARTING" ? 1090 : 765;
        if (d.Itt >= ittCritical) alerts.Add(new AlertItem("ITT LIMIT", d.Itt.ToString("0") + " C", true)); else if (d.Itt > ittWarning) alerts.Add(new AlertItem("HIGH ITT", d.Itt.ToString("0") + " C", false));
        if (d.Torque > 1970) alerts.Add(new AlertItem("TORQUE LIMIT", d.Torque.ToString("0") + " FT-LB", true)); else if (d.Torque > 1865) alerts.Add(new AlertItem("HIGH TORQUE", d.Torque.ToString("0") + " FT-LB", false));
        if (d.Ng > 102.6) alerts.Add(new AlertItem("NG LIMIT", d.Ng.ToString("0.0") + "%", true)); else if (d.Ng > 101.6) alerts.Add(new AlertItem("HIGH NG", d.Ng.ToString("0.0") + "%", false));
        if (d.PropRpm > 1900) { if (!propOverBegan.HasValue) propOverBegan = now; if (d.PropRpm > 2090) { if (!propTransientBegan.HasValue) propTransientBegan = now; if ((now - propTransientBegan.Value).TotalSeconds > 2) alerts.Add(new AlertItem("PROP TRANSIENT", d.PropRpm.ToString("0") + " RPM", true)); } else propTransientBegan = null; double sec = (now - propOverBegan.Value).TotalSeconds; if (sec > 15) alerts.Add(new AlertItem("PROP OVERSPEED LIMIT", sec.ToString("0.0") + " SEC", true)); else if (sec > 2) alerts.Add(new AlertItem("PROP OVERSPEED", d.PropRpm.ToString("0") + " RPM", false)); } else { propOverBegan = propTransientBegan = null; }
        if (d.Ng >= 52 && d.OilPressure > 0) { if (!oilBaselineBegan.HasValue) { oilBaselineBegan = now; oilPeak = d.OilPressure; } oilPeak = Math.Max(oilPeak, d.OilPressure); if (oilBaseline < 0 && (now - oilBaselineBegan.Value).TotalSeconds >= 5) oilBaseline = oilPeak; }
        bool expectedShutdown = d.OnGround && Math.Round(d.ConditionLever) == 0 && !d.StarterActive; if (oilBaseline > 0 && !expectedShutdown && (oilBaseline - d.OilPressure) / oilBaseline >= .40) alerts.Add(new AlertItem("OIL PRESSURE DROP", d.OilPressure.ToString("0") + " PSI", true));
        if (d.OilPressure > 105) alerts.Add(new AlertItem("HIGH OIL PRESSURE", d.OilPressure.ToString("0") + " PSI", true)); if (d.OilTemperature >= 104) alerts.Add(new AlertItem("OIL TEMPERATURE", d.OilTemperature.ToString("0") + " C", true)); else if (d.OilTemperature > 99) alerts.Add(new AlertItem("HIGH OIL TEMP", d.OilTemperature.ToString("0") + " C", false));
        if (d.StarterActive) { if (!starterBegan.HasValue) starterBegan = now; double sec = (now - starterBegan.Value).TotalSeconds; if (sec >= 30) alerts.Add(new AlertItem("STARTER LIMIT", sec.ToString("0") + " SEC / ABORT START", true)); } else starterBegan = null;
        int condition = (int)Math.Round(d.ConditionLever); if ((d.StarterActive || d.Ng > 5) && d.Ng < 12 && condition != 0) alerts.Add(new AlertItem("HOT START", "FUEL INTRODUCED BELOW 12% NG", true));
        double fuelDiff = Math.Abs(d.LeftFuelQuantity - d.RightFuelQuantity) * d.FuelWeightPerGallon; if (fuelDiff >= 200) alerts.Add(new AlertItem("FUEL IMBALANCE", fuelDiff.ToString("0") + " LB", fuelDiff >= 250));
        RenderAlerts(alerts);
    }

    private void RenderAlerts(List<AlertItem> alerts)
    {
        bool critical = false; for (int i = 0; i < alerts.Count; i++) if (alerts[i].Critical) critical = true;
        advisoryTitle.Text = critical ? "WARNING - ENGINE LIMIT" : alerts.Count > 0 ? "CAUTION - CHECK ENGINE" : "ENGINE PARAMETERS NORMAL"; advisoryTitle.ForeColor = critical ? Red : alerts.Count > 0 ? Amber : Green;
        List<string> lines = new List<string>(); Dictionary<string, bool> current = new Dictionary<string, bool>();
        for (int i = 0; i < alerts.Count; i++) { AlertItem a = alerts[i]; lines.Add(a.Title + "  " + a.Detail); if (a.Critical) { current[a.Title] = true; bool was = activeCritical.ContainsKey(a.Title) && activeCritical[a.Title]; if (!was) { events.Add(DateTime.Now.ToString("HH:mm:ss") + "  " + a.Title + "  " + a.Detail); RefreshLog(); } } }
        advisoryLines.Text = String.Join("     ", lines.ToArray()); activeCritical.Clear(); foreach (string k in current.Keys) activeCritical[k] = true;
        foreach (InstrumentCard c in cards.Values) c.SetSeverity(false, false); for (int i = 0; i < alerts.Count; i++) { string k = CardFor(alerts[i].Title); if (cards.ContainsKey(k)) cards[k].SetSeverity(alerts[i].Critical, !alerts[i].Critical); }
    }

    private static string CardFor(string title) { if (title.Contains("ITT")) return "itt"; if (title.Contains("TORQUE")) return "torque"; if (title.Contains("PROP")) return "propRpm"; if (title.Contains("NG")) return "ng"; if (title.Contains("OIL PRESSURE")) return "oilPressure"; if (title.Contains("OIL TEMP")) return "oilTemperature"; return ""; }
    private void RefreshLog() { eventLog.BeginUpdate(); eventLog.Items.Clear(); for (int i = 0; i < events.Count; i++) eventLog.Items.Add(events[i]); eventLog.EndUpdate(); logCount.Text = events.Count.ToString("00") + " EVENTS"; if (eventLog.Items.Count > 0) eventLog.TopIndex = eventLog.Items.Count - 1; }
    private void SetCard(string key, double value, string format, string sub, double percent) { if (cards.ContainsKey(key)) cards[key].SetValue(value.ToString(format), sub, percent); }
    private void SetBrightness(int value) { double f = value / 100.0; Color lit = Color.FromArgb((int)(80 + 159 * f), (int)(35 + 49 * f), (int)(20 + 27 * f)); foreach (InstrumentCard c in cards.Values) c.SetDisplayColor(lit); tail.ForeColor = Color.FromArgb((int)(70 + 73 * f), (int)(100 + 107 * f), (int)(55 + 63 * f)); }
    private void ResetCycle() { startCycle = startComplete = false; preLatch.Clear(); preLatchValue.Clear(); oilBaseline = -1; oilBaselineBegan = null; oilPeak = 0; shutdownBegan = null; cruise = false; cruiseCandidate = cruiseExit = null; }

    private static CruiseGuide Guide(double altitude, string title)
    {
        bool amphib = (title ?? "").ToUpperInvariant().Contains("AMPHIB"); double[,] t = amphib ? new double[,] { { 4000, 1600, 365 }, { 8000, 1500, 334 }, { 12000, 1400, 308 }, { 16000, 1335, 284 }, { 20000, 1185, 265 } } : new double[,] { { 4000, 1600, 365 }, { 8000, 1500, 334 }, { 12000, 1400, 308 }, { 16000, 1335, 284 }, { 22000, 1175, 256 } };
        int hi = 1; if (altitude <= t[0, 0]) hi = 1; else { for (hi = 1; hi < t.GetLength(0) && altitude > t[hi, 0]; hi++) { } if (hi >= t.GetLength(0)) hi = t.GetLength(0) - 1; }
        int lo = hi - 1; double ratio = Math.Max(0, Math.Min(1, (altitude - t[lo, 0]) / (t[hi, 0] - t[lo, 0]))); return new CruiseGuide { Torque = (int)(Math.Round((t[lo, 1] + (t[hi, 1] - t[lo, 1]) * ratio) / 5) * 5), Fuel = (int)Math.Round(t[lo, 2] + (t[hi, 2] - t[lo, 2]) * ratio) };
    }

    private sealed class AlertItem { internal string Title, Detail; internal bool Critical; internal AlertItem(string t, string d, bool c) { Title = t; Detail = d; Critical = c; } }
    private sealed class CruiseGuide { internal int Torque, Fuel; }
}

internal sealed class RailItem : Panel
{
    private readonly Label value; private readonly Panel lamp; private readonly Color normal, good, bad, action;
    internal RailItem(string name, Color n, Color g, Color r, Color a) { normal = n; good = g; bad = r; action = a; BackColor = Color.FromArgb(16, 18, 20); Margin = new Padding(0, 0, 0, 4); Padding = new Padding(7, 5, 6, 4); Label title = new Label { Text = name, ForeColor = Color.FromArgb(210, 205, 190), Font = new Font("Arial Narrow", 8, FontStyle.Bold), Dock = DockStyle.Top, Height = 17 }; value = new Label { Text = "---", ForeColor = n, Font = new Font("Consolas", 9, FontStyle.Bold), Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }; lamp = new Panel { Size = new Size(9, 9), Location = new Point(169, 20), BackColor = Color.FromArgb(50, 25, 25) }; Controls.Add(value); Controls.Add(title); Controls.Add(lamp); lamp.BringToFront(); }
    internal void SetState(bool ok, bool flash, string text) { value.Text = text; value.ForeColor = flash ? action : ok ? good : bad; lamp.BackColor = value.ForeColor; }
}

internal sealed class InstrumentCard : Panel
{
    private readonly Label readout, subtitle; private readonly SegmentedBar bar; private Color display;
    internal InstrumentCard(string name, string unit, Color lcd, Color label) { display = lcd; Dock = DockStyle.Fill; BackColor = Color.FromArgb(22, 26, 30); Margin = new Padding(0); Padding = new Padding(8, 6, 8, 5); Label title = new Label { Text = name, ForeColor = label, Font = new Font("Arial Narrow", 8, FontStyle.Bold), Dock = DockStyle.Top, Height = 18, TextAlign = ContentAlignment.MiddleCenter }; Label units = new Label { Text = unit, ForeColor = Color.FromArgb(150, 145, 132), Font = new Font("Arial Narrow", 7), Dock = DockStyle.Bottom, Height = 14, TextAlign = ContentAlignment.MiddleCenter }; bar = new SegmentedBar { Dock = DockStyle.Bottom, Height = 11 }; subtitle = new Label { ForeColor = Color.FromArgb(160, 155, 142), Font = new Font("Arial Narrow", 7), Dock = DockStyle.Bottom, Height = 22, TextAlign = ContentAlignment.MiddleCenter }; readout = new Label { Text = "---", ForeColor = lcd, BackColor = Color.FromArgb(7, 5, 4), Font = new Font("Consolas", 22, FontStyle.Bold), Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleRight, Padding = new Padding(0, 0, 5, 0) }; Controls.Add(readout); Controls.Add(title); Controls.Add(subtitle); Controls.Add(bar); Controls.Add(units); }
    internal void SetValue(string text, string sub, double percent) { readout.Text = text; subtitle.Text = sub; bar.Value = percent; }
    internal void SetSeverity(bool critical, bool warning) { readout.ForeColor = critical ? Color.FromArgb(255, 65, 50) : warning ? Color.FromArgb(245, 175, 55) : display; }
    internal void SetDisplayColor(Color c) { display = c; readout.ForeColor = c; }
}

internal sealed class SegmentedBar : Control
{
    private double value; internal double Value { get { return value; } set { this.value = Math.Max(0, Math.Min(100, value)); Invalidate(); } }
    internal SegmentedBar() { SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true); BackColor = Color.FromArgb(6, 8, 7); }
    protected override void OnPaint(PaintEventArgs e) { base.OnPaint(e); int gap = 2, count = 16, width = Math.Max(1, (ClientSize.Width - (count - 1) * gap) / count); int lit = (int)Math.Round(value / 100 * count); for (int i = 0; i < count; i++) { Color c = i < 11 ? Color.FromArgb(95, 205, 90) : i < 14 ? Color.FromArgb(220, 166, 55) : Color.FromArgb(235, 70, 52); if (i >= lit) c = Color.FromArgb(25, 31, 27); using (Brush b = new SolidBrush(c)) e.Graphics.FillRectangle(b, i * (width + gap), 1, width, Math.Max(1, ClientSize.Height - 2)); } }
}
