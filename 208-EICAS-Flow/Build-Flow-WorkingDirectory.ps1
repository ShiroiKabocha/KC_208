param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot 'Source'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot 'WorkingDirectory')
)

$ErrorActionPreference = 'Stop'

$dashboardPath = Join-Path $SourceRoot 'Dashboard.html'
$portraitCssPath = Join-Path $SourceRoot 'PortraitMode.css'
$portraitJsPath = Join-Path $SourceRoot 'PortraitMode.js'

$dashboard = Get-Content -LiteralPath $dashboardPath -Raw
$portraitCss = Get-Content -LiteralPath $portraitCssPath -Raw
$portraitJs = Get-Content -LiteralPath $portraitJsPath -Raw

$styleMatch = [regex]::Match($dashboard, '<style>([\s\S]*?)</style>')
$bodyMatch = [regex]::Match($dashboard, '<body>([\s\S]*?)<script>')
$scriptMatch = [regex]::Match($dashboard, '<script>([\s\S]*?)</script>\s*<script src="PortraitMode\.js[^>]*></script>')
if (-not ($styleMatch.Success -and $bodyMatch.Success -and $scriptMatch.Success)) {
    throw 'Could not extract the dashboard HTML, CSS, and JavaScript.'
}

$html = $bodyMatch.Groups[1].Value.Trim()
$html = $html -replace '<div id="firstRunNotice"[\s\S]*?</div>\s*</div>', ''

$flowOverrides = @'

/* Flow Pro host overrides */
:root { color-scheme: dark; }
body { background: transparent !important; overflow: hidden !important; }
#app {
  position: fixed;
  inset: 18px;
  width: auto;
  height: auto;
  max-width: none;
  margin: 0;
  overflow: auto;
  z-index: 2147483000;
  box-shadow: 0 12px 55px rgba(0,0,0,.8);
}
#app.flow-hidden { display: none !important; }
#firstRunNotice { display: none !important; }
@media (max-width: 900px) {
  #app { inset: 8px; }
}
'@
$css = $styleMatch.Groups[1].Value.Trim() + "`r`n`r`n" + $portraitCss.Trim() + "`r`n" + $flowOverrides

$dashboardJs = $scriptMatch.Groups[1].Value.Trim()
$dashboardJs = $dashboardJs -replace "const firstRunNotice=\$\('firstRunNotice'\);[\s\S]*?firstRunNotice\.hidden=true\}\);", "var firstRunNotice=`$('firstRunNotice'); if(firstRunNotice){firstRunNotice.hidden=true;}"
$dashboardJs = $dashboardJs -replace "refresh\(\);setInterval\(refresh,100\);", "refresh(); flowRefreshTimer=setInterval(refresh,100);"
$dashboardJs = $dashboardJs -replace 'for\(const ch of value\)\{', 'for(var flowCharIndex=0;flowCharIndex<value.length;flowCharIndex++){const ch=value.charAt(flowCharIndex);'
$dashboardJs = $dashboardJs -replace 'tm\.append\(clock,sev\);', 'tm.appendChild(clock);tm.appendChild(sev);'
$dashboardJs = $dashboardJs -replace 'row\.append\(tm,name,detail,status\);', 'row.appendChild(tm);row.appendChild(name);row.appendChild(detail);row.appendChild(status);'
$dashboardJs = [regex]::Replace($dashboardJs, 'async function refresh\(\)\{[\s\S]*?\n\}', @'
function refresh(){
  return fetch('/api/data',{cache:'no-store'})
    .then(function(r){return r.json();})
    .then(function(d){
      const operational=!!d.connected&&!!d.aircraftCompatible;
      $('app').classList.toggle('offline',!operational);
      setConnection(operational,d.message);
      if(operational)render(d);else resetStartSequence();
    })
    .catch(function(){resetStartSequence();$('app').classList.add('offline');setConnection(false,'Flow data bridge offline');});
}
'@)
$dashboardJs = [regex]::Replace($dashboardJs, "const powerButton=\$\('powerButton'\);[\s\S]*?powerButton\.addEventListener\('keyup',[\s\S]*?\}\);", @'
const powerButton=$('powerButton');
if(powerButton){
  powerButton.title='Close 208 EICAS';
  powerButton.addEventListener('click',function(){
    if(flowRoot){flowRoot.classList.add('flow-widget-hidden');}
    var app=$('app');if(app){app.classList.add('flow-hidden');}
  });
}
'@)

$adapter = @'
var flowRoot = null;
var flowRefreshTimer = null;
var flowApi = this.$api;

if(!String.prototype.padStart){
  String.prototype.padStart=function(length,pad){
    var value=String(this);pad=String(pad||' ');
    while(value.length<length){value=pad+value;}
    return value.slice(value.length-length);
  };
}

function flowNumber(name, unit) {
  try {
    var value = Number(flowApi.variables.get(name, unit));
    return Number.isFinite(value) ? value : 0;
  } catch (error) { return 0; }
}

function flowString(name) {
  try { return String(flowApi.variables.get(name, 'string') || ''); }
  catch (error) { return ''; }
}

function readDashboardData() {
  var title = flowString('A:TITLE');
  var compatible = /CARAVAN|C208|208B/i.test(title);
  return {
    connected: true,
    aircraftCompatible: compatible,
    message: compatible ? 'Connected to Black Square Caravan.' : 'Load the Black Square Caravan Professional.',
    itt: flowNumber('L:BKSQ_CARAVAN_ITT', 'number'),
    heading: flowNumber('L:BKSQ_MagneticCompassHeading', 'number'),
    headingBug: flowNumber('A:AUTOPILOT HEADING LOCK DIR', 'degrees'),
    course: flowNumber('A:NAV OBS:1', 'degrees'),
    torque: flowNumber('L:BKSQ_CARAVAN_TQ', 'number'),
    ng: flowNumber('L:BKSQ_CARAVAN_NG', 'number'),
    fuelPressure: flowNumber('L:BKSQ_CARAVAN_FUELPRESSURE', 'psi'),
    propRpm: flowNumber('A:PROP RPM:1', 'rpm'),
    fuelFlow: flowNumber('L:BKSQ_CARAVAN_FuelFlow', 'number') * 6.7,
    oilPressure: flowNumber('A:ENG OIL PRESSURE:1', 'psi'),
    oilTemperature: flowNumber('L:BKSQ_CARAVAN_OILTEMPERATURE', 'celsius'),
    oat: flowNumber('A:AMBIENT TEMPERATURE', 'celsius'),
    onGround: flowNumber('A:SIM ON GROUND', 'bool') >= 0.5,
    starter: flowNumber('A:GENERAL ENG STARTER:1', 'bool') >= 0.5,
    starterActive: flowNumber('A:GENERAL ENG STARTER ACTIVE:1', 'bool') >= 0.5,
    agl: flowNumber('A:PLANE ALT ABOVE GROUND', 'feet'),
    pressureAltitude: flowNumber('A:PRESSURE ALTITUDE', 'feet'),
    verticalSpeed: flowNumber('A:VERTICAL SPEED', 'feet per minute'),
    fuelSelector: flowNumber('A:FUEL TANK SELECTOR:1', 'enum'),
    leftFuelQuantity: flowNumber('A:FUEL TANK LEFT MAIN QUANTITY', 'gallons'),
    rightFuelQuantity: flowNumber('A:FUEL TANK RIGHT MAIN QUANTITY', 'gallons'),
    fuelWeightPerGallon: flowNumber('A:FUEL WEIGHT PER GALLON', 'pounds'),
    fuelCutoffHandle: flowNumber('L:var_FuelCutoffHandle', 'number'),
    firewallCutoffHandle: flowNumber('L:var_FirewallCutoffHandle', 'number'),
    batteryMaster: flowNumber('A:ELECTRICAL MASTER BATTERY:1', 'bool') >= 0.5,
    busVoltage: flowNumber('A:ELECTRICAL MAIN BUS VOLTAGE:1', 'volts'),
    fuelPumpSwitch: flowNumber('L:var_FuelPumpSwitch', 'number'),
    conditionLever: flowNumber('L:BKSQ_ConditionLever', 'number'),
    engineCovers: flowNumber('L:bksq_EngineCovers', 'bool') >= 0.5,
    propLeverPosition: flowNumber('A:GENERAL ENG PROPELLER LEVER POSITION:1', 'percent'),
    powerLeverPosition: flowNumber('A:GENERAL ENG THROTTLE LEVER POSITION:1', 'percent'),
    inertialSeparator: flowNumber('L:XMLVAR_InterSep', 'bool') >= 0.5,
    tailNumber: flowString('A:ATC ID'),
    aircraftTitle: title
  };
}

var originalFetch = window.fetch ? window.fetch.bind(window) : null;
window.fetch = function(input, init) {
  var url = typeof input === 'string' ? input : (input && input.url) || '';
  if(url.indexOf('/api/data') >= 0) {
    return Promise.resolve({ok:true,status:200,json:function(){return Promise.resolve(readDashboardData());}});
  }
  if(url.indexOf('/api/shutdown') >= 0) {
    return Promise.resolve({ok:true,status:200,json:function(){return Promise.resolve({ok:true});}});
  }
  return originalFetch ? originalFetch(input,init) : Promise.reject(new Error('Fetch unavailable'));
};

run(function() {
  if(flowRoot){flowRoot.classList.remove('flow-widget-hidden');}
  var app=document.getElementById('app');if(app){app.classList.remove('flow-hidden');}
  return true;
});

state(function(){ return '208'; });
info(function(){ return 'Black Square Caravan engine and start monitor'; });

html_created(function(el) {
  flowRoot = el;
'@

$footer = @'
});

exit(function() {
  if(flowRefreshTimer){clearInterval(flowRefreshTimer);flowRefreshTimer=null;}
  window.fetch=originalFetch;
});
'@

$portraitJs = $portraitJs -replace 'var button = event\.target\.closest\("button\[data-efb-view\]"\);', "var button=event.target;while(button&&button!==tabs&&!button.getAttribute('data-efb-view'))button=button.parentNode;if(button===tabs)button=null;"
$combinedJs = $adapter + "`r`n" + $dashboardJs + "`r`n" + $portraitJs.Trim() + "`r`n" + $footer

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
Set-Content -LiteralPath (Join-Path $OutputRoot 'code.html') -Value $html -Encoding utf8
Set-Content -LiteralPath (Join-Path $OutputRoot 'code.css') -Value $css -Encoding utf8
Set-Content -LiteralPath (Join-Path $OutputRoot 'code.js') -Value $combinedJs -Encoding utf8

Write-Host "Flow working directory created: $OutputRoot"
Get-ChildItem -LiteralPath $OutputRoot | Select-Object Name, Length
