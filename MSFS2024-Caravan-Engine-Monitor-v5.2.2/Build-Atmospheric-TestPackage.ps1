$ErrorActionPreference = 'Stop'

$project = $PSScriptRoot
$workspace = Split-Path $project -Parent
$packageName = '208-EICAS-Atmospheric-Modules-Test-2'
$stage = Join-Path $workspace $packageName
$zip = Join-Path $workspace ($packageName + '.zip')
$temp = Join-Path $env:TEMP ('208-eicas-atmospheric-' + [guid]::NewGuid().ToString('N'))

if (Test-Path -LiteralPath $stage) { throw "Package target already exists: $stage" }
if (Test-Path -LiteralPath $zip) { throw "Package archive already exists: $zip" }
New-Item -ItemType Directory -Path $stage | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage 'Assets') | Out-Null
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    # Reuse the exact atmospheric generator state, but discard its mock API.
    . (Join-Path $project 'Build-Atmospheric-Preview.ps1')
    $mockStart = $mock.IndexOf('window.fetch=function(url){', [StringComparison]::Ordinal)
    $runtimeStart = $mock.IndexOf("document.addEventListener('DOMContentLoaded'", [StringComparison]::Ordinal)
    if ($mockStart -lt 0 -or $runtimeStart -le $mockStart) { throw 'Could not separate the atmospheric runtime enhancements from the preview API stub.' }
    $runtimeScript = $mock.Remove($mockStart, $runtimeStart - $mockStart)
    # Keep enhancement helpers module-scoped instead of adding another set of globals.
    $runtimeScript = $runtimeScript.Replace('<script>', '<script type="module">')
    $productionHtml = $html.Replace($mock, '').Replace('refresh();', 'refresh();setInterval(refresh,100);')
    $productionHtml = $productionHtml.Replace('<strong class="fd-value">168</strong>', '<strong id="trueAirspeedHeader" class="fd-value">---</strong>')
    $headerUpdates = @'
  $('trueAirspeedHeader').textContent=Number(d.trueAirspeed).toFixed(0);
'@
    $productionHtml = $productionHtml.Replace('function render(d){', "function render(d){`r`n" + $headerUpdates)
    # Turn the original application script into a module and route its DOM work
    # through the small manager. The enhancement script remains a plain script.
    $moduleImports = @'
<script type="module">
import {DOMManager} from '/WebRuntime/DOMManager.js';
import {FlightPhysics} from '/WebRuntime/FlightPhysics.js';
import {DashboardController} from '/WebRuntime/DashboardController.js';
'@
    $productionHtml = [regex]::Replace($productionHtml, '<script>', $moduleImports.TrimEnd(), 1)
    $productionHtml = $productionHtml.Replace('const $=id=>document.getElementById(id);', 'const dom=new DOMManager(document);')
    $productionHtml = [regex]::Replace($productionHtml, '\$\(([^\r\n\)]*)\)', 'dom.byId($1)')
    # The old helper quietly returned null for optional decorations. Keep the
    # strict lookup for real hardware, but not for targets/bars that may be absent.
    $productionHtml = $productionHtml.Replace('const te=dom.byId(', 'const te=dom.optional(')
    $productionHtml = $productionHtml.Replace('const se=dom.byId(', 'const se=dom.optional(')
    $productionHtml = $productionHtml.Replace('const be=dom.byId(', 'const be=dom.optional(')
    $productionHtml = [regex]::Replace($productionHtml, '(?m)^let starterBegan=.*?\r?\n^let cruiseCandidateBegan=.*?\r?\n^let oilBaseline=.*?\r?\n', '')
    $physicsRegion = '(?s)function pushAlert\(a,severity,title,detail\).*?(?=function render\(d\)\{)'
    if (-not [regex]::IsMatch($productionHtml, $physicsRegion)) { throw 'Could not locate the legacy aviation-physics block.' }
    $productionHtml = [regex]::Replace($productionHtml, $physicsRegion, '')
    $productionHtml = $productionHtml.Replace('function render(d){', 'function render(d,a){')
    $productionHtml = $productionHtml.Replace('  const a=analyze(d);', '')
    $productionHtml = $productionHtml.Replace('normalCruiseGuide(d.pressureAltitude,d.aircraftTitle)', 'physics.cruiseGuide(d.pressureAltitude,d.aircraftTitle)')
    $refreshRegion = '(?s)async function refresh\(\)\{.*?\n\}\s+\nconst displayDimmer='
    if (-not [regex]::IsMatch($productionHtml, $refreshRegion)) { throw 'Could not locate the legacy telemetry polling block.' }
    $productionHtml = [regex]::Replace($productionHtml, $refreshRegion, 'const displayDimmer=')
    $controllerBootstrap = @'
const physics=new FlightPhysics();
const controller=new DashboardController({
  renderTelemetry:({data,analysis})=>{setConnection(true,data.message);render(data,analysis)},
  onOffline:(error)=>{resetStartSequence();setConnection(false,error.message)}
});
controller.start(100);
'@
    $productionHtml = $productionHtml.Replace('refresh();setInterval(refresh,100);', $controllerBootstrap.Trim())
    $productionHtml = $productionHtml.Replace('</body>', $runtimeScript + "`r`n</body>")
    Set-Content -LiteralPath (Join-Path $stage 'Dashboard.html') -Value $productionHtml -Encoding utf8

    $source = Get-Content -LiteralPath (Join-Path $project 'Program.cs') -Raw
    $localhostMain = @'
    [STAThread]
    public static void Main()
    {
        bool firstInstance;
        _singleInstance = new Mutex(true, "Local\\Kabocha208EICASAtmosphericTest", out firstInstance);
        if (!firstInstance)
        {
            MessageBox.Show("208 EICAS is already running.", "208 EICAS", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        if (!PrepareSimConnect())
        {
            MessageBox.Show("SimConnect.dll could not be loaded.\n\nExtract the complete package and keep SimConnect.dll beside 208 EICAS.exe.", "208 EICAS - SimConnect Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            _singleInstance.ReleaseMutex();
            _singleInstance.Dispose();
            return;
        }
        Thread simThread = new Thread(SimLoop);
        simThread.IsBackground = true;
        simThread.Start();
        HttpListener listener = new HttpListener();
        listener.Prefixes.Add("http://localhost:8765/");
        listener.Start();
        Thread serverThread = new Thread(delegate()
        {
            while (_running)
            {
                try
                {
                    HttpListenerContext context = listener.GetContext();
                    ThreadPool.QueueUserWorkItem(delegate { Serve(context); });
                }
                catch { if (_running) Thread.Sleep(100); }
            }
        });
        serverThread.IsBackground = true;
        serverThread.Start();
        StartTrayIcon();
        OpenDashboard();
        while (_running) Thread.Sleep(100);
        try { listener.Stop(); listener.Close(); } catch { }
        Disconnect();
        try { _singleInstance.ReleaseMutex(); } catch { }
        _singleInstance.Dispose();
    }

'@
    $mainPattern = '(?s)    \[STAThread\]\s+public static void Main\(\)\s+\{.*?\n    \}\s+\n    internal static void BeginShutdown\(\)'
    if (-not [regex]::IsMatch($source, $mainPattern)) { throw 'Could not locate the desktop Main method in Program.cs.' }
    $source = [regex]::Replace($source, $mainPattern, $localhostMain + '    internal static void BeginShutdown()', 1)
    $source = $source.Replace('private static double _pressureAltitude;', "private static double _pressureAltitude;`r`n    private static double _trueAirspeed;")
    $addAtmosphere = @'
Add("PRESSURE ALTITUDE", "feet");
                    Add("AIRSPEED TRUE", "knots");
'@
    $source = $source.Replace('Add("PRESSURE ALTITUDE", "feet");', $addAtmosphere.Trim())
    $source = $source.Replace('const int fieldCount = 32;', 'const int fieldCount = 33;')
    $source = $source.Replace('double pressureAltitude = ReadDouble(pData, o); o += 8;', "double pressureAltitude = ReadDouble(pData, o); o += 8;`r`n        double trueAirspeed = ReadDouble(pData, o); o += 8;")
    $source = $source.Replace('_pressureAltitude = pressureAltitude;', "_pressureAltitude = pressureAltitude;`r`n            _trueAirspeed = trueAirspeed;")
    $jsonAtmosphere = @'
"\"pressureAltitude\":" + N(_pressureAltitude) + "," +
                "\"trueAirspeed\":" + N(_trueAirspeed) + "," +
'@
    $source = $source.Replace('"\"pressureAltitude\":" + N(_pressureAltitude) + "," +', $jsonAtmosphere.Trim())

    $newRoot = @'
else if (path.StartsWith("/Assets/", StringComparison.OrdinalIgnoreCase) || path.StartsWith("/WebRuntime/", StringComparison.OrdinalIgnoreCase))
                WriteAsset(context, path);
            else if (path == "/" || path.Equals("/index.html", StringComparison.OrdinalIgnoreCase))
            {
                string dashboard = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Dashboard.html");
                Write(context, File.Exists(dashboard) ? File.ReadAllText(dashboard, Encoding.UTF8) : Html, "text/html; charset=utf-8", 200);
}
'@
    $rootPattern = 'else if \(path == "/" \|\| path\.Equals\("/index\.html", StringComparison\.OrdinalIgnoreCase\)\)\s+Write\(context, Html, "text/html; charset=utf-8", 200\);'
    if (-not [regex]::IsMatch($source, $rootPattern)) { throw 'Could not locate the localhost root route in Program.cs.' }
    $source = [regex]::Replace($source, $rootPattern, $newRoot.TrimEnd(), 1)

    $writeAsset = @'

    private static void WriteAsset(HttpListenerContext context, string requestPath)
    {
        string relative = Uri.UnescapeDataString(requestPath.TrimStart('/')).Replace('/', Path.DirectorySeparatorChar);
        string root = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
        string file = Path.GetFullPath(Path.Combine(root, relative));
        if (!file.StartsWith(root, StringComparison.OrdinalIgnoreCase) || !File.Exists(file))
        {
            Write(context, "Not found", "text/plain; charset=utf-8", 404);
            return;
        }
        string ext = Path.GetExtension(file).ToLowerInvariant();
        string type = ext == ".png" ? "image/png" : ext == ".jpg" || ext == ".jpeg" ? "image/jpeg" : ext == ".svg" ? "image/svg+xml" : ext == ".js" ? "text/javascript; charset=utf-8" : "application/octet-stream";
        byte[] bytes = File.ReadAllBytes(file);
        context.Response.StatusCode = 200;
        context.Response.ContentType = type;
        context.Response.ContentLength64 = bytes.Length;
        context.Response.Headers["Cache-Control"] = "public, max-age=86400";
        context.Response.OutputStream.Write(bytes, 0, bytes.Length);
        context.Response.Close();
    }
'@
    $source = $source.Replace('    private static void WriteIcon(HttpListenerContext context)', $writeAsset + "`r`n    private static void WriteIcon(HttpListenerContext context)")
    $testSource = Join-Path $temp 'Program.AtmosphericTest.cs'
    Set-Content -LiteralPath $testSource -Value $source -Encoding utf8

    $assets = @(
        'avionics-body-wrinkle-black.png',
        'cessna-identification-placard.png',
        'lamp-red-lit.png',
        'lamp-red-unlit.png',
        'lamp-green-lit.png',
        'lamp-green-unlit.png',
        'cruise208-clean.png',
        'engine-rack-cream-pebble.png',
        'indicator-lamps-sprite.png',
        'KABOCHAsafetylabel.png',
        'notebook-cubby-inset.png',
        'panel-texture-charcoal-seamless.png'
    )
    foreach ($asset in $assets) {
        Copy-Item -LiteralPath (Join-Path (Join-Path $project 'Assets') $asset) -Destination (Join-Path (Join-Path $stage 'Assets') $asset)
    }
    Copy-Item -LiteralPath (Join-Path $project 'WebRuntime') -Destination $stage -Recurse
    Copy-Item -LiteralPath (Join-Path $project 'SimConnect.dll') -Destination $stage
    Copy-Item -LiteralPath (Join-Path $project 'PACKAGING-README.txt') -Destination (Join-Path $stage 'README.txt')
    Copy-Item -LiteralPath (Join-Path $project 'PACKAGING-CHANGELOG.txt') -Destination (Join-Path $stage 'CHANGELOG.txt')
    Copy-Item -LiteralPath (Join-Path $project 'START-DASHBOARD.cmd') -Destination $stage

    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ("/win32icon:" + (Join-Path $project 'Kabocha208.ico')) ("/out:" + (Join-Path $stage '208 EICAS.exe')) $testSource (Join-Path $project 'DesktopDashboard.cs')
    if ($LASTEXITCODE -ne 0) { throw "Compiler failed with exit code $LASTEXITCODE" }

    Compress-Archive -LiteralPath $stage -DestinationPath $zip -CompressionLevel Optimal
    Write-Host "Created $stage"
    Write-Host "Created $zip"
}
catch {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    throw
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
