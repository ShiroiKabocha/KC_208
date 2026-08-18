$ErrorActionPreference = 'Stop'
$programPath = Join-Path $PSScriptRoot 'Program.cs'
$previewPath = Join-Path $PSScriptRoot 'Dashboard-Preview-Atmospheric.html'
$source = Get-Content -LiteralPath $programPath -Raw
$match = [regex]::Match($source, 'private const string Html = @"([\s\S]*?)";\s*\r?\n\}')
if (-not $match.Success) { throw 'Embedded dashboard HTML was not found.' }
$html = $match.Groups[1].Value.Replace('""','"')

function Convert-NotebookPage {
    param([string]$Title, [string[]]$Lines)
    $encode = { param($value) [Net.WebUtility]::HtmlEncode($value.Trim()) }
    $out = New-Object Text.StringBuilder
    [void]$out.Append('<h2>' + (& $encode $Title) + '</h2>')
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('## ')) {
            $heading = [regex]::Replace($line.Substring(3), '\s+\{#[^}]+\}\s*$', '')
            [void]$out.Append('<h3>' + (& $encode $heading) + '</h3>')
            continue
        }
        if ($line.StartsWith('> ')) { [void]$out.Append('<p class="manual-note">' + (& $encode $line.Substring(2)) + '</p>'); continue }
        if ($line.StartsWith('|')) {
            $rows = @()
            while ($i -lt $Lines.Count -and $Lines[$i].Trim().StartsWith('|')) { $rows += ,($Lines[$i].Trim().Trim('|').Split('|') | ForEach-Object {$_.Trim()}); $i++ }
            $i--
            [void]$out.Append('<table>')
            for ($r = 0; $r -lt $rows.Count; $r++) {
                if ($r -eq 1 -and (($rows[$r] -join '') -match '^-+$')) { continue }
                $tag = if ($r -eq 0) {'th'} else {'td'}
                [void]$out.Append('<tr>')
                foreach ($cell in $rows[$r]) { [void]$out.Append('<' + $tag + '>' + (& $encode $cell) + '</' + $tag + '>') }
                [void]$out.Append('</tr>')
            }
            [void]$out.Append('</table>')
            continue
        }
        [void]$out.Append('<p>' + (& $encode $line) + '</p>')
    }
    return $out.ToString()
}

function Read-NotebookPages {
    param([string]$Path)
    $pages = [ordered]@{}
    $title = $null; $key = $null; $lines = New-Object Collections.Generic.List[string]
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ($line -match '^#\s+(.+?)\s+\{#([a-z0-9-]+)\}\s*$') {
            if ($key) {
                $pages[$key] = [pscustomobject]@{
                    Title = $title
                    Html = Convert-NotebookPage -Title $title -Lines $lines.ToArray()
                }
            }
            $title = $matches[1]; $key = $matches[2]; $lines.Clear(); continue
        }
        if ($key) { $lines.Add($line) }
    }
    if ($key) {
        $pages[$key] = [pscustomobject]@{
            Title = $title
            Html = Convert-NotebookPage -Title $title -Lines $lines.ToArray()
        }
    }
    return $pages
}

$extraCss = @'
<style>
.flight-data-strip{display:flex;align-items:center;justify-content:flex-end;flex-wrap:wrap;gap:7px;margin-right:3px}
.flight-data-window{position:relative;display:grid;grid-template-columns:auto auto;align-items:end;column-gap:7px;min-width:116px;padding:5px 9px 4px;overflow:hidden;border:1px solid #0b0d0b;border-right-color:#383c35;border-bottom-color:#55584f;border-radius:4px;background:linear-gradient(180deg,#030503,#0b100d 53%,#030504);box-shadow:inset 0 5px 9px #000,inset 3px 0 5px rgba(0,0,0,.78),inset -1px -1px 2px rgba(132,143,115,.12),0 0 0 1px #242820,0 2px 3px rgba(0,0,0,.72)}
.flight-data-window:after{content:"";position:absolute;z-index:2;inset:1px;border-radius:3px;background:linear-gradient(135deg,rgba(255,255,255,.07) 0 44%,rgba(255,255,255,.015) 45%,transparent 47% 100%);pointer-events:none}
.flight-data-window>*{position:relative;z-index:3}
.flight-data-window .fd-label{grid-column:1/-1;margin-bottom:2px;color:#aaa697;font:700 8px "Arial Narrow","Segoe UI",sans-serif;letter-spacing:.16em;text-transform:uppercase}
.flight-data-window .fd-value{color:#e8c96a;font:700 15px Consolas,"Courier New",monospace;line-height:1;text-shadow:0 0 4px rgba(232,201,106,.38)}
.flight-data-window .fd-unit{padding-bottom:1px;color:#b6a66e;font:700 8px Consolas,"Courier New",monospace;letter-spacing:.08em;text-shadow:0 0 3px rgba(232,201,106,.2)}
.flight-data-window.altitude{min-width:132px}
.theme-picker{display:grid;gap:2px;min-width:142px}.theme-picker label{color:#85877e;font:700 7px "Arial Narrow","Segoe UI",sans-serif;letter-spacing:.16em;text-transform:uppercase}.theme-picker select{height:25px;padding:2px 24px 2px 7px;color:var(--theme-select-text,#d8d5c7);background:var(--theme-select,#171a1c);border:1px solid var(--theme-accent,#4a5054);font:700 9px "Arial Narrow","Segoe UI",sans-serif;letter-spacing:.08em;text-transform:uppercase;outline:none}
.hardware-mounted{position:relative}.hardware-mounted:before,.hardware-mounted:after,.instrument:before,.instrument:after,.rack-section:before,.rack-section:after,.monitor-module:before,.monitor-module:after{display:none!important}.mount-screw{position:absolute;z-index:8;width:11px;height:11px;border:1px solid #070807;border-radius:50%;background:conic-gradient(from 22deg,#101110 0 8%,#777a75 18%,#242624 34%,#969993 49%,#30322f 66%,#111210 83%,#656862 100%);box-shadow:inset 1px 1px 2px rgba(255,255,255,.3),inset -1px -1px 2px rgba(0,0,0,.8),1px 2px 3px rgba(0,0,0,.9);pointer-events:none}.mount-screw:after{content:"";position:absolute;left:2px;right:2px;top:4px;height:1.5px;border-radius:1px;background:#090a09;box-shadow:0 1px rgba(255,255,255,.12);transform:rotate(var(--slot-angle,-16deg))}.mount-screw.tl{left:5px;top:5px;--slot-angle:-18deg}.mount-screw.tr{right:5px;top:5px;--slot-angle:11deg}.mount-screw.bl{left:5px;bottom:5px;--slot-angle:24deg}.mount-screw.br{right:5px;bottom:5px;--slot-angle:-8deg}
.hardware-mounted.start-rail{padding-left:16px;padding-right:16px}.hardware-mounted.advisory-housing{padding:18px 17px 15px}.hardware-mounted.monitor-module{padding:9px}.hardware-mounted.navigation-rack{padding-left:17px;padding-right:17px;padding-bottom:17px}.hardware-mounted.event-log{padding:17px}.instrument .label:after{right:15px}
main[data-theme]{--theme-body:#0e1011;--theme-panel:#08090a;--theme-edge:#353a3e;--theme-rack:#11151a;--theme-card:#171b20;--theme-recess:#070a0c;--theme-label:#ddd9c8;--theme-muted:#9d998c;--theme-accent:#596067;--theme-lcd:#ef542f;--theme-glow:rgba(239,84,47,.22);--theme-select:#171a1c;--theme-select-text:#d8d5c7;background-color:var(--theme-panel);color:var(--theme-label);box-shadow:inset 0 0 0 2px var(--theme-edge),inset 0 0 34px rgba(0,0,0,.55),0 8px 24px #000}
main[data-theme]{width:min(1740px,calc(100vw - 24px));margin:18px auto 8px;overflow-x:hidden;container-type:inline-size;container-name:eicas-panel;outline:1px solid rgba(55,43,24,.9);border-radius:4px;box-shadow:inset 0 0 0 2px var(--theme-edge),inset 0 0 34px rgba(0,0,0,.62),0 0 0 3px #786c50,0 0 0 7px #b8aa82,0 0 0 9px rgba(69,54,31,.7),3px 8px 13px rgba(0,0,0,.72)}main[data-theme] .dashboard-body{grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:10px}main[data-theme] .rail-bank{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
@container eicas-panel (min-width:1100px){main[data-theme] .dashboard-body{grid-template-columns:minmax(350px,422px) minmax(0,1fr) minmax(200px,250px)}}
.dimmer-panel{display:none!important}.cockpit-environment{position:fixed;z-index:0;inset:0;pointer-events:none}.aircraft-placard-wrap{position:absolute;z-index:1;left:18px;bottom:16px;width:min(270px,22vw);filter:drop-shadow(0 5px 5px rgba(47,34,15,.72))}.aircraft-placard{display:block;width:100%;height:auto;clip-path:inset(1.4% 1.2% 1.6% 1.2% round 6px);object-fit:contain}.brand-logo{position:relative;z-index:2;display:block;width:min(330px,36vw);height:auto;margin:0;filter:drop-shadow(2px 3px 2px rgba(0,0,0,.62));pointer-events:none}.title-row{position:relative;z-index:2;min-height:0}.tail-number{display:none!important}main[data-theme]{position:relative;z-index:10}main[data-theme] header{position:relative;z-index:4;overflow:visible;background-color:#0b0d0c;background-image:linear-gradient(112deg,rgba(255,255,255,.028),transparent 35% 72%,rgba(0,0,0,.22)),url("Assets/avionics-body-wrinkle-black.png");background-repeat:no-repeat,repeat;background-position:center;background-size:cover,320px auto}
.background-vignette{position:absolute;z-index:2;inset:0;pointer-events:none;background:radial-gradient(ellipse 72% 66% at 50% 47%,transparent 30%,rgba(39,29,15,.18) 52%,rgba(20,15,8,.62) 79%,rgba(6,4,2,.94) 100%)}
body:has(main[data-theme="caravan-utility"]),body:has(main[data-theme="caravan-textured"]){background-color:#d7c89d;background-image:linear-gradient(112deg,rgba(255,255,255,.07),transparent 38% 72%,rgba(78,62,33,.07)),url("Assets/engine-rack-cream-pebble.png");background-repeat:no-repeat,repeat;background-position:center,center;background-size:cover,360px auto;background-attachment:fixed,fixed}body:has(main[data-theme="trainer-red"]){background:#171313}body:has(main[data-theme="bonanza-blue"]){background:#0d1319}body:has(main[data-theme="piper-heritage"]){background:#11161b}body:has(main[data-theme="cirrus-carbon"]){background:#101113}
main[data-theme] header{border-bottom:0}main[data-theme] h1,main[data-theme] .label,main[data-theme] .rail-title,main[data-theme] .start-name,main[data-theme] .section-title{color:var(--theme-label)}main[data-theme] .instrument,main[data-theme] .start-item,main[data-theme] .aux-card{background-color:var(--theme-card);border-color:var(--theme-edge)}main[data-theme] .readout{color:var(--theme-lcd);text-shadow:0 0 7px var(--theme-glow)}main[data-theme] .unit,main[data-theme] .sub,main[data-theme] .start-target{color:var(--theme-muted)}main[data-theme] .flight-data-window{border-color:var(--theme-accent)}
main[data-theme] .aux-grid{background:transparent;border-color:transparent}
main[data-theme] .rail-title{border-bottom:0}
main[data-theme] .engine-rack>.section-title{display:none}
main[data-theme] .active-sequence-rail .rail-subtitle{display:none}
.cruise-placard-wrap{position:absolute;z-index:3;left:20px;bottom:18px;width:310px;filter:drop-shadow(3px 7px 6px rgba(0,0,0,.88));pointer-events:none}.cruise-placard{display:block;width:100%;height:auto;clip-path:inset(7.2% .9% 9.2% .9% round 6px)}
.safety-label{position:absolute;z-index:20;left:18px;bottom:16px;display:block;width:min(300px,21vw);height:auto;clip-path:inset(4.5% 2% 5.5% 2% round 5px);filter:drop-shadow(2px 4px 3px rgba(0,0,0,.7));pointer-events:none}
.notebook-cubby{position:absolute;z-index:12;left:50%;top:0;width:310px;height:78px;padding:0;transform:translateX(-50%);border:0;border-radius:7px;background:transparent;box-shadow:0 0 0 2px rgba(8,9,8,.85),1px 4px 5px rgba(0,0,0,.72);overflow:visible;cursor:pointer}.notebook-tab{display:block;width:100%;height:100%;object-fit:fill;border:0;border-radius:7px;filter:none;transition:transform .14s ease}.notebook-cubby:hover .notebook-tab{transform:translateY(-2px)}
.manual-overlay{position:fixed;z-index:5000;inset:0;display:grid;place-items:center;padding:24px;background:rgba(6,5,3,.72);backdrop-filter:blur(3px);opacity:0;visibility:hidden;transition:opacity .18s ease,visibility .18s ease}.manual-overlay.open{opacity:1;visibility:visible}.manual-book{position:relative;width:min(960px,92vw);height:min(690px,88vh);padding:44px 38px 28px 58px;border-radius:9px 16px 16px 9px;background:linear-gradient(90deg,#a77945 0 18px,#76502e 19px 28px,#eee9da 29px 49.5%,#c6bdab 50%,#f3eedf 50.5% 100%);box-shadow:0 20px 55px #000,0 0 0 3px #3c2818,inset 0 0 38px rgba(90,72,45,.16);color:#24282b;font-family:Arial,Helvetica,sans-serif;transform:translateY(12px) scale(.98);transition:transform .2s ease}.manual-overlay.open .manual-book{transform:none}.manual-book:before{content:"";position:absolute;z-index:4;left:25px;top:25px;bottom:25px;width:22px;background:repeating-linear-gradient(180deg,#151515 0 5px,#555 6px 8px,#101010 9px 20px);border-radius:8px;box-shadow:3px 0 4px rgba(0,0,0,.55)}.manual-book:after{content:"";position:absolute;left:50%;top:18px;bottom:18px;width:2px;background:rgba(76,52,25,.18);box-shadow:-5px 0 11px rgba(50,30,12,.12),5px 0 11px rgba(255,255,255,.45)}.manual-close{position:absolute;z-index:8;right:15px;top:13px;width:31px;height:31px;border:1px solid #4a331f;border-radius:50%;background:radial-gradient(circle at 35% 30%,#aaa18f,#514a3e 48%,#211d18 70%);box-shadow:inset 1px 1px 2px rgba(255,255,255,.4),2px 3px 4px rgba(0,0,0,.55);color:#eee7d5;font:bold 18px Arial;cursor:pointer}.manual-tabs{position:absolute;z-index:6;right:-38px;top:75px;display:grid;gap:7px}.manual-tab{width:78px;padding:8px 7px;border:1px solid #5e4328;border-radius:0 6px 6px 0;background:#b98b4f;box-shadow:2px 3px 4px rgba(0,0,0,.45);color:#2f2418;font:700 10px "Arial Narrow",Arial,sans-serif;letter-spacing:.07em;text-align:right;text-transform:uppercase;cursor:pointer}.manual-tab.active{background:#e9d59f;transform:translateX(-8px)}.manual-page{display:none;height:100%;overflow:auto;padding:3px 24px 10px 18px;column-count:2;column-gap:64px;column-rule:1px solid rgba(90,63,31,.18);background-color:rgba(255,255,255,.07);background-image:repeating-linear-gradient(180deg,transparent 0 27px,rgba(82,111,147,.09) 28px);font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.48}.manual-page.active{display:block}.manual-page h2,.manual-page h3{break-after:avoid;font-family:"Arial Narrow",Arial,Helvetica,sans-serif;text-transform:uppercase}.manual-page h2{margin:0 0 14px;padding-bottom:7px;border-bottom:2px solid rgba(48,64,92,.55);font-size:22px;font-weight:800;letter-spacing:.055em}.manual-page h3{margin:17px 0 4px;font-size:13px;font-weight:800;letter-spacing:.045em;text-decoration:none}.manual-page p{margin:0 0 10px}.manual-page table{width:100%;margin:8px 0 14px;border-collapse:collapse;background:rgba(255,255,255,.23);font:11px Arial,Helvetica,sans-serif;break-inside:avoid}.manual-page th,.manual-page td{padding:5px 6px;border:1px solid rgba(54,68,91,.35);text-align:right}.manual-page th{font-family:"Arial Narrow",Arial,sans-serif;font-weight:800;letter-spacing:.035em;text-transform:uppercase}.manual-page th:first-child,.manual-page td:first-child{text-align:left}.manual-note{padding:7px 9px;border:1px solid rgba(111,80,34,.55);background:rgba(229,202,126,.2);font-weight:bold;break-inside:avoid}@media(max-width:760px){.manual-page{column-count:1}.manual-tabs{right:8px;top:auto;bottom:-31px;display:flex}.manual-tab{width:auto;border-radius:0 0 5px 5px}.manual-book{padding-right:24px}}
main[data-theme="caravan-utility"]{--theme-panel:#08090a;--theme-edge:#353a3e;--theme-rack:#11151a;--theme-card:#171b20;--theme-label:#ddd9c8;--theme-muted:#9d998c;--theme-accent:#596067;--theme-lcd:#ef542f}
main[data-theme="caravan-textured"]{--theme-panel:#08090a;--theme-edge:#3d4245;--theme-rack:#11151a;--theme-card:#171b20;--theme-label:#ddd9c8;--theme-muted:#9d998c;--theme-accent:#62686b;--theme-lcd:#ef542f}
main[data-theme="caravan-textured"]{background-color:#0b0d0c;background-image:linear-gradient(112deg,rgba(255,255,255,.035),transparent 35% 72%,rgba(0,0,0,.24)),url("Assets/avionics-body-wrinkle-black.png");background-repeat:no-repeat,repeat;background-position:center,center;background-size:cover,420px auto;box-shadow:inset 0 0 0 2px #363a37,inset 0 0 34px rgba(0,0,0,.62),0 8px 24px #000}
main[data-theme="caravan-textured"] .instrument,main[data-theme="caravan-textured"] .start-item,main[data-theme="caravan-textured"] .aux-card{background-color:#17191a;background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 32% 72%,rgba(0,0,0,.25)),url("Assets/panel-texture-charcoal-seamless.png");background-repeat:no-repeat,no-repeat;background-position:center,center;background-size:cover,cover;background-blend-mode:normal,normal;box-shadow:inset 0 1px rgba(255,255,255,.035),inset 0 -3px 8px rgba(0,0,0,.52)}
main[data-theme="caravan-textured"] .monitor-module{background-color:#17191a;background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 32% 72%,rgba(0,0,0,.25)),url("Assets/panel-texture-charcoal-seamless.png");background-repeat:no-repeat,repeat-x;background-position:center,left center;background-size:cover,25% 100%;box-shadow:inset 0 1px rgba(255,255,255,.045),inset 0 -7px 15px rgba(0,0,0,.48),1px 1px 0 #595d60}
main[data-theme="caravan-textured"] .monitor-module .instrument{background-color:transparent;background-image:none;box-shadow:none}
main[data-theme="caravan-textured"] .engine-rack{border:0;box-shadow:none;padding-left:0;padding-right:0;padding-bottom:0}
main[data-theme="caravan-textured"] .start-rail,main[data-theme="caravan-textured"] .engine-rack,main[data-theme="caravan-textured"] .advisory-housing,main[data-theme="caravan-textured"] .event-log,main[data-theme="caravan-textured"] .event-log-controls{background-color:#0b0d0c;background-image:linear-gradient(112deg,rgba(255,255,255,.028),transparent 35% 72%,rgba(0,0,0,.22)),url("Assets/avionics-body-wrinkle-black.png");background-repeat:no-repeat,repeat;background-position:center,center;background-size:cover,320px auto}
main[data-theme="caravan-textured"] .advisory-housing{position:relative;margin:10px 0 0;border:2px solid #050607;box-shadow:inset 0 0 0 1px #3b4248,inset 0 0 18px rgba(0,0,0,.62),1px 1px 0 #4d5255}
main[data-theme="caravan-textured"] .advisory-housing .advisory-title{margin:0 7px 8px}
main[data-theme="caravan-textured"] .advisory-housing .alert-panel{box-sizing:border-box;height:94px;min-height:94px;max-height:94px;overflow:hidden;margin:0;padding:10px 13px;background-color:#080b08;background-image:linear-gradient(180deg,rgba(255,255,255,.018),transparent 34%),repeating-linear-gradient(0deg,transparent 0 3px,rgba(130,190,115,.018) 3px 4px);border:2px inset #343b34;box-shadow:inset 0 6px 13px #000,inset 2px 0 4px rgba(0,0,0,.8),inset -1px -1px rgba(110,125,104,.1)}
main[data-theme="caravan-textured"] .navigation-rack{background-color:#17191a;background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 32% 72%,rgba(0,0,0,.25)),url("Assets/panel-texture-charcoal-seamless.png");background-repeat:no-repeat,repeat-x;background-position:center,left center;background-size:cover,20% 100%;box-shadow:inset 0 1px rgba(255,255,255,.045),inset 0 -7px 15px rgba(0,0,0,.48),1px 1px 0 #4d5255}
main[data-theme="caravan-textured"] .navigation-rack .instrument{background:transparent;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .navigation-rack .instrument .label:after{display:none}
main[data-theme="caravan-textured"] .start-list{margin-top:8px;padding:7px;background-color:#17191a;background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 32% 72%,rgba(0,0,0,.25)),url("Assets/panel-texture-charcoal-seamless.png");background-repeat:no-repeat,repeat-y;background-position:center,center top;background-size:cover,100% 25%;border:2px solid #050607;box-shadow:inset 0 0 0 1px #343936,inset 0 0 13px rgba(0,0,0,.52)}
main[data-theme="caravan-textured"] .start-list .start-item{background:transparent;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .advisory-housing{background-color:#17191a;background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 32% 72%,rgba(0,0,0,.25)),url("Assets/panel-texture-charcoal-seamless.png");background-repeat:no-repeat,repeat;background-position:center,center;background-size:cover,320px auto;border:2px solid #050607;box-shadow:inset 0 0 0 1px #343936,inset 0 0 13px rgba(0,0,0,.52),1px 1px 0 #4d5255}
main[data-theme="caravan-textured"] .instrument-area{background-color:transparent;background-image:none;border-color:transparent}
main[data-theme="caravan-textured"] .readout{background-color:#060807;background-image:none}
main[data-theme="caravan-textured"] .instrument .readout{margin-left:7px;margin-right:7px;border:1px solid #151817;border-radius:6px;clip-path:none;color:#f05b36;background:linear-gradient(180deg,#020303 0,#060807 48%,#030504 100%);box-shadow:inset 0 5px 8px rgba(0,0,0,.92),inset 3px 0 5px rgba(0,0,0,.65),inset -2px -2px 3px rgba(73,78,72,.12),0 0 0 2px #252926,0 2px 3px rgba(0,0,0,.78);text-shadow:0 0 2px rgba(255,105,65,.78),0 0 7px rgba(239,84,47,.38),0 0 13px rgba(239,84,47,.14)}
main[data-theme="caravan-textured"] .monitor-module .instrument .readout{position:relative;isolation:isolate;overflow:hidden;border:1px solid #050605;border-radius:7px;outline:2px solid #292d2a;background:#020303!important;background-image:none!important;box-shadow:inset 0 9px 14px #000,inset 4px 0 7px rgba(0,0,0,.8),inset -2px -2px 3px rgba(146,156,146,.14),0 4px 6px rgba(0,0,0,.72)}
main[data-theme="caravan-textured"] .monitor-module .instrument .readout:before{content:"";display:block!important;position:absolute;z-index:0;inset:0;width:auto;height:auto;border:0;border-radius:6px;background:linear-gradient(145deg,#252a28 0,#080a09 23%,#020303 72%,#111411 100%);box-shadow:none;pointer-events:none}
main[data-theme="caravan-textured"] .monitor-module .instrument .readout:after{content:"";position:absolute;z-index:2;inset:2px;border-radius:5px;background:linear-gradient(135deg,rgba(255,255,255,.085) 0 44%,rgba(255,255,255,.018) 45%,transparent 47% 100%);pointer-events:none}
main[data-theme="caravan-textured"] .monitor-module .instrument .readout>span{position:relative;z-index:3}
main[data-theme="caravan-textured"] .monitor-module .readout{font-size:42px}
main[data-theme="caravan-textured"] .monitor-module:nth-child(2) .instrument .readout{font-size:42px}
main[data-theme="caravan-textured"] .monitor-module .readout>span{display:inline-block;transform:translateY(3px)}
.numeric-segment-display{display:flex!important;align-items:center;justify-content:flex-end;width:100%;height:1em;gap:.052em;transform:translateY(0)!important;color:inherit}.numeric-segment-char{display:block;width:.57em;height:1em;overflow:visible}.numeric-segment-char.segment-dot{width:.2em;transform:translateY(7px)}.numeric-segment-char line,.numeric-segment-char circle{stroke:currentColor;stroke-width:6.4;stroke-linecap:round;fill:currentColor;opacity:.052}.numeric-segment-char .on{opacity:1;filter:drop-shadow(0 0 1.7px currentColor)}
main[data-theme="caravan-textured"] .power-button,main[data-theme="caravan-textured"] .clr-last{border-top-color:#626663;box-shadow:0 4px 5px rgba(0,0,0,.72),inset 0 1px 0 rgba(255,255,255,.16),inset 0 -2px 3px rgba(0,0,0,.7)}
main[data-theme="caravan-textured"] .monitor-module:nth-child(2) .instrument{min-height:92px;padding-top:7px;padding-bottom:5px}
main[data-theme="caravan-textured"] .monitor-module:nth-child(2) .instrument .readout{margin-top:5px;margin-bottom:2px;padding-top:2px}
main[data-theme="caravan-textured"] .monitor-module:nth-child(2) .instrument .limit,main[data-theme="caravan-textured"] .monitor-module:nth-child(2) .instrument .scale{display:none!important}
main[data-theme="caravan-textured"] .monitor-module:first-child .instrument{min-height:142px;padding-bottom:8px}
main[data-theme="caravan-textured"] .monitor-module:first-child .instrument .scale{display:none!important}
main[data-theme="caravan-textured"] .monitor-module:first-child .instrument .limit{box-sizing:border-box;display:flex;align-items:center;justify-content:center;width:calc(100% - 18px);height:31px;min-height:31px;margin:9px 9px 0;padding:4px 7px;overflow:hidden;border:1px solid #050705;border-radius:3px;outline:1px solid #30352d;background-color:#101b0d;background-image:linear-gradient(180deg,rgba(149,190,95,.08),transparent 38%),repeating-linear-gradient(0deg,rgba(112,150,78,.025) 0 2px,transparent 2px 4px);box-shadow:inset 0 5px 9px rgba(0,0,0,.9),inset 2px 0 4px rgba(0,0,0,.72),inset -1px -1px 2px rgba(142,164,113,.13),0 2px 3px rgba(0,0,0,.72);color:#a8cf79;font:700 11px "Lucida Console",Consolas,monospace;line-height:1.1;letter-spacing:.025em;text-align:center;text-shadow:0 0 3px rgba(141,207,94,.48);white-space:nowrap}
main[data-theme="caravan-textured"] .start-item{background-color:#10130f;background-image:linear-gradient(180deg,#12150f,#090c09 72%,#11130e);border:2px inset #4b4941;box-shadow:inset 0 3px 10px #020302,inset 0 0 0 1px rgba(144,160,126,.06),0 1px rgba(255,255,255,.035)}
main[data-theme="caravan-textured"] .start-list{gap:0}
main[data-theme="caravan-textured"] .start-item{box-sizing:border-box;height:39px;min-height:39px;padding-top:4px;padding-bottom:4px;background:transparent;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .start-item .start-name{color:#d6d1c1;font-family:"Arial Narrow","Segoe UI",Arial,sans-serif;font-weight:800;letter-spacing:.09em;text-shadow:0 1px #000}
main[data-theme="caravan-textured"] .start-item .start-value{display:flex;align-items:center;gap:10px;min-height:22px;margin:4px 17px 0 0;padding:2px 7px;color:#e6a84b;background:linear-gradient(180deg,#030403,#080a07 62%,#050604);border:1px solid #020302;border-top-color:#000;border-left-color:#000;border-right-color:#34372f;border-bottom-color:#45483f;outline:1px solid #171914;box-shadow:inset 0 4px 8px #000,inset 2px 0 4px rgba(0,0,0,.9),inset -1px -1px 2px rgba(119,126,101,.13),0 2px 0 #050605,0 3px 3px rgba(0,0,0,.7);font-family:"Lucida Console",Consolas,"Courier New",monospace;font-weight:700;text-shadow:0 0 3px rgba(230,168,75,.32)}
main[data-theme="caravan-textured"] .start-item .start-target{display:none}
main[data-theme="caravan-textured"] #start-voltage-value{display:none}
main[data-theme="caravan-textured"] .start-item.ready,main[data-theme="caravan-textured"] .start-item.pending,main[data-theme="caravan-textured"] .start-item.blocked{border:0}
main[data-theme="caravan-textured"] .start-item.ready .start-value,main[data-theme="caravan-textured"] .start-item.pending .start-value,main[data-theme="caravan-textured"] .start-item.blocked .start-value{color:#e6a84b;text-shadow:0 0 3px rgba(230,168,75,.32)}
main[data-theme="caravan-textured"] .start-item .inline-voltage{color:#c9ad70;text-shadow:none}
main[data-theme="caravan-textured"] .start-item.action-ready .start-value{color:#ffd17a;text-shadow:0 0 4px rgba(255,190,83,.55);animation:hardwarePrompt .82s steps(1,end) infinite}
main[data-theme="caravan-textured"] .start-item .state-lamp{position:relative;width:13px;height:13px;border:2px solid #070807;background:radial-gradient(circle at 36% 30%,#5e6258 0 8%,#242722 18% 48%,#080908 67%);box-shadow:0 0 0 1px #484a43,1px 2px 2px #000,inset 0 0 2px #000;animation:none}
main[data-theme="caravan-textured"] .start-item .state-lamp{position:relative;width:15px;height:15px;border:0;background-image:url("Assets/indicator-lamps-sprite.png");background-repeat:no-repeat;background-size:220% 220%;background-position:100% 0;box-shadow:-1px -2px 3px #000;transform:rotate(180deg);animation:none;overflow:hidden}
main[data-theme="caravan-textured"] .start-item .state-lamp:before{display:block;content:"";position:absolute;inset:24%;z-index:1;border-radius:50%;background:rgba(0,32,8,.68);box-shadow:inset 0 0 2px rgba(0,0,0,.8);pointer-events:none}
main[data-theme="caravan-textured"] .start-item.ready .state-lamp{background-image:url("Assets/indicator-lamps-sprite.png");background-position:100% 0;box-shadow:-1px -2px 3px #000,0 0 5px rgba(98,220,64,.34);transform:rotate(180deg);animation:none}
main[data-theme="caravan-textured"] .start-item.ready .state-lamp:before{opacity:0}
main[data-theme="caravan-textured"] .start-item.pending .state-lamp,main[data-theme="caravan-textured"] .start-item.action-ready .state-lamp,main[data-theme="caravan-textured"] .start-item.time-warning .state-lamp,main[data-theme="caravan-textured"] .start-item.blocked .state-lamp,main[data-theme="caravan-textured"] .start-item.abort-action .state-lamp{background-image:url("Assets/indicator-lamps-sprite.png");background-position:100% 0;box-shadow:-1px -2px 3px #000;transform:rotate(180deg);animation:none}
main[data-theme="caravan-textured"] .start-item>div{display:flex;align-items:center;height:100%}
main[data-theme="caravan-textured"] .start-item .start-value{display:none}
main[data-theme="caravan-textured"] .instrument .label:after{width:15px;height:15px;border:0;background-image:url("Assets/indicator-lamps-sprite.png");background-repeat:no-repeat;background-size:220% 220%;background-position:100% 100%;box-shadow:1px 2px 3px #000;animation:none}
main[data-theme="caravan-textured"] .instrument .label:before{content:"";position:absolute;z-index:2;right:18px;top:11px;width:8px;height:8px;border-radius:50%;background:rgba(48,0,0,.76);box-shadow:inset 0 0 2px #000;pointer-events:none}
main[data-theme="caravan-textured"] .instrument.warn .label:after,main[data-theme="caravan-textured"] .instrument.crit .label:after{background-image:url("Assets/indicator-lamps-sprite.png");background-position:100% 100%;animation:none}
main[data-theme="caravan-textured"] .instrument.warn .label:before,main[data-theme="caravan-textured"] .instrument.crit .label:before{animation:photoLensFlash .82s steps(1,end) infinite}
main[data-theme="caravan-textured"] .instrument.warn .label:before{animation-duration:1.15s}
main[data-theme="caravan-textured"] .navigation-rack .instrument .label:before{display:none}
main[data-theme="caravan-textured"] .start-item{grid-template-columns:30px minmax(0,1fr)}
main[data-theme="caravan-textured"] .start-item:before{visibility:hidden}
main[data-theme="caravan-textured"] .start-item>div{grid-column:2;padding-left:0}
main[data-theme="caravan-textured"] .start-item .state-lamp{position:absolute;left:4px;top:20%;width:25px;height:25px;border:0;background:none;box-shadow:none;transform:none;overflow:visible;animation:none}
main[data-theme="caravan-textured"] .start-item .state-lamp:before{display:none}
main[data-theme="caravan-textured"] .photo-lamp{position:absolute;inset:0;width:100%;height:100%;display:block;object-fit:cover;clip-path:circle(47% at 50% 50%);transform:none;filter:none;pointer-events:none}
main[data-theme="caravan-textured"] .photo-lamp.lit{opacity:0;z-index:2}
main[data-theme="caravan-textured"] .photo-lamp.unlit{opacity:1;z-index:1}
main[data-theme="caravan-textured"] .start-item.ready .photo-lamp.lit{opacity:1}
main[data-theme="caravan-textured"] .start-item.ready .photo-lamp.unlit{opacity:0}
main[data-theme="caravan-textured"] .instrument .label:before,main[data-theme="caravan-textured"] .instrument .label:after{display:none!important}
main[data-theme="caravan-textured"] .instrument .label{position:relative}
main[data-theme="caravan-textured"] .instrument .label .lamp-stack{position:absolute;right:15px;top:-4px;width:20px;height:20px}
main[data-theme="caravan-textured"] .instrument.warn .photo-lamp.lit,main[data-theme="caravan-textured"] .instrument.crit .photo-lamp.lit{opacity:1;animation:none}
@keyframes photoImageFlash{0%,44%{opacity:1}45%,100%{opacity:0}}
@keyframes photoLensFlash{0%,44%{opacity:0}45%,100%{opacity:1}}
@keyframes hardwarePrompt{50%{opacity:.38}}
main[data-theme="trainer-red"]{--theme-panel:#181615;--theme-edge:#78685b;--theme-rack:#29231f;--theme-card:#342c27;--theme-recess:#100b09;--theme-label:#f0e7d5;--theme-muted:#bea993;--theme-accent:#a8493f;--theme-lcd:#ffd27a;--theme-glow:rgba(255,187,90,.25);--theme-select:#2a211d;--theme-select-text:#f0e7d5;background-image:linear-gradient(110deg,rgba(235,229,213,.07),transparent 32%),repeating-linear-gradient(90deg,rgba(155,49,42,.08) 0 2px,transparent 2px 12px)}
main[data-theme="bonanza-blue"]{--theme-panel:#0d1822;--theme-edge:#536e83;--theme-rack:#142737;--theme-card:#1b3244;--theme-recess:#06101a;--theme-label:#e3edf3;--theme-muted:#94adbd;--theme-accent:#3c82ac;--theme-lcd:#7fc7ef;--theme-glow:rgba(86,178,230,.28);--theme-select:#102738;--theme-select-text:#dcecf5;background-image:linear-gradient(135deg,rgba(75,145,187,.12),transparent 38% 72%,rgba(3,8,12,.3))}
main[data-theme="piper-heritage"]{--theme-panel:#101923;--theme-edge:#817257;--theme-rack:#172638;--theme-card:#213249;--theme-recess:#07111c;--theme-label:#eee6d3;--theme-muted:#b3aa96;--theme-accent:#b18b45;--theme-lcd:#f0c96d;--theme-glow:rgba(238,186,73,.25);--theme-select:#18283a;--theme-select-text:#eee6d3;background-image:linear-gradient(120deg,rgba(231,222,197,.06),transparent 30%),repeating-linear-gradient(0deg,rgba(177,139,69,.025) 0 1px,transparent 1px 7px)}
main[data-theme="cirrus-carbon"]{--theme-panel:#111214;--theme-edge:#4e5258;--theme-rack:#1a1c20;--theme-card:#24272c;--theme-recess:#08090b;--theme-label:#eef0f1;--theme-muted:#9ca1a5;--theme-accent:#93b52a;--theme-lcd:#cbe75d;--theme-glow:rgba(185,224,55,.26);--theme-select:#202328;--theme-select-text:#e9ecee;background-image:linear-gradient(135deg,rgba(255,255,255,.045),transparent 30%),repeating-linear-gradient(45deg,rgba(255,255,255,.012) 0 2px,transparent 2px 6px)}
main[data-theme="local-rental"]{--theme-panel:#171713;--theme-edge:#55564b;--theme-rack:#24241d;--theme-card:#292a23;--theme-recess:#090a07;--theme-label:#d4d0bc;--theme-muted:#918e7f;--theme-accent:#686556;--theme-lcd:#e45b38;--theme-glow:rgba(228,91,56,.18);--theme-select:#24231d;--theme-select-text:#d5d0bc;background-image:linear-gradient(104deg,rgba(188,181,146,.055),transparent 21% 64%,rgba(0,0,0,.28)),repeating-linear-gradient(7deg,rgba(255,255,255,.014) 0 1px,transparent 1px 8px),linear-gradient(73deg,transparent 0 47%,rgba(201,195,164,.08) 47.2% 47.5%,transparent 47.7%)}
main[data-theme="local-rental"]:before{content:"";position:absolute;left:18%;top:9px;width:1px;height:94%;background:rgba(202,198,170,.14);transform:rotate(-.5deg);box-shadow:2px 0 rgba(0,0,0,.5);pointer-events:none;z-index:4}
main[data-theme="local-rental"] .start-rail,main[data-theme="local-rental"] .monitor-module,main[data-theme="local-rental"] .aux-grid{background-image:linear-gradient(118deg,transparent 0 33%,rgba(196,192,163,.09) 33.2% 33.45%,transparent 33.7%),linear-gradient(82deg,transparent 0 71%,rgba(0,0,0,.45) 71.2% 71.6%,transparent 71.8%)}
main[data-theme="local-rental"] .readout{position:relative;background-image:linear-gradient(127deg,transparent 0 69%,rgba(210,220,204,.22) 69.3% 69.6%,transparent 69.9%),linear-gradient(54deg,transparent 0 77%,rgba(210,220,204,.13) 77.3% 77.55%,transparent 77.8%);box-shadow:inset 0 0 11px #000,inset 0 0 0 1px rgba(210,210,190,.08)}
main[data-theme="local-rental"] .instrument:nth-child(3) .readout{animation:rentalFlickerA 3.7s infinite}main[data-theme="local-rental"] .monitor-module:nth-of-type(2) .instrument:nth-child(2) .readout{animation:rentalFlickerB 5.1s infinite}
main[data-theme="local-rental"] .instrument:nth-child(3):after{content:"INOP?";position:absolute;right:4px;top:35px;padding:1px 5px;background:#c7bb94;color:#302e25;font:700 7px "Arial Narrow",Arial,sans-serif;letter-spacing:.08em;transform:rotate(7deg);box-shadow:0 1px 2px #000;z-index:3}main[data-theme="local-rental"] .aux-card:nth-child(2):after{content:"INTERMITTENT";position:absolute;right:3px;bottom:3px;padding:1px 4px;background:#bcae89;color:#302e25;font:700 6px "Arial Narrow",Arial,sans-serif;letter-spacing:.06em;transform:rotate(-4deg);box-shadow:0 1px 2px #000;z-index:3}
main[data-theme="local-rental"] .instrument,main[data-theme="local-rental"] .aux-card{position:relative}main[data-theme="local-rental"] h1{opacity:.76;text-shadow:1px 1px #000}
@keyframes rentalFlickerA{0%,8%,11%,38%,42%,72%,76%,100%{opacity:1}9%,10%,39%,40%{opacity:.18}41%,74%{opacity:.56}73%,75%{opacity:.05}}@keyframes rentalFlickerB{0%,21%,24%,62%,65%,91%,100%{filter:none}22%,23%,63%{filter:brightness(.2)}64%{filter:brightness(1.8)}92%{filter:brightness(.45)}}
main[data-theme="local-rental"]{position:relative}
/* Raised line-replaceable module housings; screens within remain recessed. */
main[data-theme="caravan-textured"] .start-rail,
main[data-theme="caravan-textured"] .advisory-housing,
main[data-theme="caravan-textured"] .monitor-module,
main[data-theme="caravan-textured"] .navigation-rack,
main[data-theme="caravan-textured"] .event-log{
  position:relative;
  border-top:1px solid #5b605c;
  border-left:1px solid #414642;
  border-right:1px solid #0b0d0c;
  border-bottom:2px solid #070807;
  border-radius:5px;
  box-shadow:inset 0 1px 0 rgba(255,255,255,.11),inset 1px 0 0 rgba(255,255,255,.035),inset 0 -1px 0 rgba(0,0,0,.5),2px 5px 7px rgba(0,0,0,.72),0 1px 1px rgba(0,0,0,.8)
}
main[data-theme="caravan-textured"] .start-rail,
main[data-theme="caravan-textured"] .advisory-housing,
main[data-theme="caravan-textured"] .monitor-module,
main[data-theme="caravan-textured"] .navigation-rack,
main[data-theme="caravan-textured"] .event-log{
  background-color:#17191a;
  background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 32% 72%,rgba(0,0,0,.25)),url("Assets/panel-texture-charcoal-seamless.png");
  background-repeat:no-repeat,repeat;
  background-position:center,center top;
  background-size:cover,240px auto
}
main[data-theme="caravan-textured"] .navigation-rack .instrument .readout{
  position:relative;isolation:isolate;overflow:hidden;border:1px solid #050605;border-radius:7px;outline:2px solid #292d2a;
  background:#020303!important;background-image:none!important;
  box-shadow:inset 0 9px 14px #000,inset 4px 0 7px rgba(0,0,0,.8),inset -2px -2px 3px rgba(146,156,146,.14),0 4px 6px rgba(0,0,0,.72)
}
main[data-theme="caravan-textured"] .navigation-rack .instrument .readout:before{
  content:"";display:block!important;position:absolute;z-index:0;inset:0;width:auto;height:auto;border:0;border-radius:6px;
  background:linear-gradient(145deg,#252a28 0,#080a09 23%,#020303 72%,#111411 100%);box-shadow:none;pointer-events:none
}
main[data-theme="caravan-textured"] .navigation-rack .instrument .readout:after{
  content:"";position:absolute;z-index:2;inset:2px;border-radius:5px;
  background:linear-gradient(135deg,rgba(255,255,255,.085) 0 44%,rgba(255,255,255,.018) 45%,transparent 47% 100%);pointer-events:none
}
main[data-theme="caravan-textured"] .navigation-rack .instrument .readout>span{position:relative;z-index:3}
@media (min-width:1200px) and (max-height:1000px){main[data-theme="caravan-textured"]{margin-top:9px;padding:10px 12px 11px}main[data-theme="caravan-textured"] header{padding-bottom:6px}main[data-theme="caravan-textured"] .dashboard-body{gap:8px}main[data-theme="caravan-textured"] .instrument-area{gap:7px}}
:root{--layer-cockpit:0;--layer-dashboard:10;--layer-modal:100;--layer-toast:110}
.cockpit-environment{z-index:var(--layer-cockpit)}main[data-theme]{z-index:var(--layer-dashboard)}.manual-overlay{z-index:var(--layer-modal)}.first-run-notice{z-index:var(--layer-toast)}
@media(max-width:900px){header{grid-template-columns:1fr}.header-actions{justify-content:flex-end;flex-wrap:wrap}.flight-data-strip{flex-wrap:wrap}.flight-data-window{min-width:110px}}
</style>
'@
$strip = @'
<div class="flight-data-strip" aria-label="Atmospheric and flight reference data">
  <div class="flight-data-window"><span class="fd-label">True airspeed</span><strong class="fd-value">168</strong><span class="fd-unit">KT TAS</span></div>
</div>
'@
$html = $html.Replace('</head>', $extraCss + "`r`n</head>")
$html = $html.Replace('<main id="app" class="offline">', '<main id="app" data-theme="caravan-textured">')
$html = $html.Replace('<h1>Kabocha 208 EICAS</h1>', '<img class="brand-logo" src="Assets/cruise208-clean.png" alt="Kabocha Cruise 208">')
$html = $html.Replace('<div class="header-actions">', '<div class="header-actions">' + $strip)
$html = $html.Replace('<div id="simStatus" class="sim-status offline"', '<div id="simStatus" class="sim-status connected"')
$html = $html.Replace('<div id="tailNumber" class="tail-number">--------</div>', '<div id="tailNumber" class="tail-number">N2500A</div>')
$html = $html.Replace('refresh();setInterval(refresh,100);', 'refresh();')
$badMiddleDot = ([string][char]0x00C2) + ([string][char]0x00B7)
$badDegree = ([string][char]0x00C2) + ([string][char]0x00B0)
$html = $html.Replace($badMiddleDot,' / ').Replace($badDegree,'').Replace(([string][char]0x00B0),'')
$html = $html.Replace('FLIGHT READY','READY')
$html = [regex]::Replace($html, '(?s)(<div id="start-condition".*?<div class="start-name">)Condition lever(</div>)', '$1Condition-Cutoff$2', 1)
$html = [regex]::Replace($html, '(?s)(<div id="seq-condition".*?<div class="start-name">)Condition lever(</div>)', '$1Condition-Low Idle$2', 1)
$html = [regex]::Replace($html, '(?s)(<div id="seq-starter".*?<div class="start-name">)Starter(</div>)', '$1Starter Off$2', 1)
$html = [regex]::Replace($html, '(?s)(<div id="seq-pump".*?<div class="start-name">)Boost pump(</div>)', '$1Boost Pump Off$2', 1)
$html = $html.Replace('<div class="rail-title">Start sequence<div class="rail-subtitle">Active start / final actions</div></div>', '<div class="rail-title">Above 12% Ng</div>')

$mock = @'
<script>
window.fetch=function(url){
  if(String(url).indexOf('/api/data')>=0)return Promise.resolve({json:function(){return Promise.resolve({
    connected:true,aircraftCompatible:true,message:'Preview data',tailNumber:'N2500A',aircraftTitle:'Black Square Caravan Professional Gear N2500A',
    itt:755,torque:1715,ng:98.6,propRpm:2120,oilPressure:91,oilTemperature:78,fuelPressure:14.1,fuelFlow:326,
    heading:247,headingBug:260,course:255,oat:12,onGround:false,agl:7450,pressureAltitude:8450,trueAirspeed:168,verticalSpeed:15,
    starter:false,starterActive:false,fuelSelector:1,leftFuelQuantity:63,rightFuelQuantity:61,fuelWeightPerGallon:6.7,
    fuelCutoffHandle:1,firewallCutoffHandle:1,batteryMaster:true,busVoltage:28.2,fuelPumpSwitch:1,conditionLever:1,
    engineCovers:false,propLeverPosition:100,powerLeverPosition:25,inertialSeparator:true
  });}});
  return Promise.resolve({json:function(){return Promise.resolve({ok:true});}});
};
document.addEventListener('DOMContentLoaded',function(){
  var app=document.getElementById('app');
  if(!app)return;
  var dimmerPanel=document.querySelector('.dimmer-panel');if(dimmerPanel)dimmerPanel.remove();
  var environment=document.createElement('div'),placardWrap=document.createElement('div'),placard=document.createElement('img'),vignette=document.createElement('div');environment.className='cockpit-environment';placardWrap.className='aircraft-placard-wrap';placard.className='aircraft-placard';placard.src='Assets/cessna-identification-placard.png';placard.alt='Cessna aircraft identification placard';vignette.className='background-vignette';placardWrap.appendChild(placard);environment.appendChild(placardWrap);environment.appendChild(vignette);document.body.appendChild(environment);
  var safetyLabel=document.createElement('img');safetyLabel.className='safety-label';safetyLabel.src='Assets/KABOCHAsafetylabel.png';safetyLabel.alt='Kabocha avionics safety and identification labels';app.appendChild(safetyLabel);
  var header=document.querySelector('#app>header');
  var notebookCubby=document.createElement('button');
  var notebookTab=document.createElement('img');

  notebookCubby.className='notebook-cubby';
  notebookCubby.type='button';
  notebookCubby.title='Open dashboard notebook';
  notebookCubby.setAttribute('aria-label','Open dashboard notebook');

  notebookTab.className='notebook-tab';
  notebookTab.src='Assets/notebook-cubby-inset.png';
  notebookTab.alt='';
  notebookCubby.appendChild(notebookTab);
  if(header)header.appendChild(notebookCubby);
  var manual=document.createElement('div');manual.className='manual-overlay';manual.innerHTML='<section class="manual-book" role="dialog" aria-modal="true" aria-label="Kabocha Cruise 208 manual"><button class="manual-close" type="button" aria-label="Close manual">&times;</button><nav class="manual-tabs"><button class="manual-tab active" data-page="quick">Quick Start</button><button class="manual-tab" data-page="takeoff">Takeoff</button><button class="manual-tab" data-page="climb">Climb</button><button class="manual-tab" data-page="cruise">Cruise</button><button class="manual-tab" data-page="alerts">Alerts</button></nav><article class="manual-page active" data-page="quick"><h2>Kabocha Cruise 208</h2><p class="manual-note">Reference aid only. Aircraft manuals and current operating limitations remain authoritative.</p><h3>Purpose</h3><p>The display organizes startup readiness, engine monitoring, flight references, live advisories, and recorded critical limit events.</p><h3>Startup workflow</h3><p>Complete Pre-start Checks from top to bottom. Start Setup then verifies condition lever, battery, boost pump, and starter readiness. During Start Sequence, follow the highlighted instruction at the appropriate Ng threshold.</p><h3>Advisories</h3><p>The upper display shows current conditions. Critical exceedances receive the suffix EVENT LOGGED and are retained in the Critical Advisory Log. CLR LAST removes only the newest recorded event.</p><h3>Flight phase</h3><p>On-ground operation defaults to TAKEOFF. Airborne operation is CLIMB until vertical speed remains between -100 and +100 feet per minute for five seconds, then CRUISE becomes active.</p><h3>Display colors</h3><p>Orange-red numerals are normal display illumination. Green lamps mark completed startup states. Red lamps identify limit activity on primary engine cards.</p></article><article class="manual-page" data-page="takeoff"><h2>Takeoff limits</h2><table><tr><th>Parameter</th><th>Reference</th></tr><tr><td>ITT</td><td>805 C max</td></tr><tr><td>Torque</td><td>1865 ft-lb continuous</td></tr><tr><td>Ng</td><td>OAT-adjusted limit</td></tr><tr><td>Propeller</td><td>1900 RPM max operating</td></tr></table><h3>Transient references</h3><p>Torque above 1970 ft-lb is treated as a critical limit. Torque above 2400 ft-lb is a transient event. Propeller speed above 2090 RPM for more than two seconds is immediately logged as a critical event.</p><h3>Ng temperature correction</h3><p>The baseline Ng limit is 101.6 percent at OAT -30 C and warmer. Below -30 C, the displayed limit decreases by 2.2 percentage points for each additional 10 C colder.</p><p class="manual-note">Use the small reference LCDs on the four primary cards for the active phase values.</p></article><article class="manual-page" data-page="climb"><h2>Climb references</h2><table><tr><th>Parameter</th><th>Reference</th></tr><tr><td>ITT</td><td>740 C continuous</td></tr><tr><td>Torque</td><td>1865 ft-lb max</td></tr><tr><td>Ng</td><td>OAT-adjusted limit</td></tr><tr><td>Propeller</td><td>1900 RPM max</td></tr></table><h3>Phase behavior</h3><p>Any airborne state that has not satisfied the stabilized-cruise timer is treated as CLIMB. Cruise exits after vertical speed remains outside the +/-100 FPM band for two seconds.</p><h3>Engine handling</h3><p>As altitude increases, ITT generally becomes the governing power limit before torque. Set power by the applicable aircraft chart and remain below every displayed hard limit.</p></article><article class="manual-page" data-page="cruise"><h2>Interpolated cruise</h2><p>Kabocha Cruise interpolates suggested normal-cruise torque and fuel flow from pressure altitude. These are practical reference targets, not mandatory power settings.</p><table><tr><th>Pressure altitude</th><th>Torque</th><th>Fuel flow</th></tr><tr><td>4,000 ft</td><td>1600 ft-lb</td><td>365 PPH</td></tr><tr><td>8,000 ft</td><td>1500 ft-lb</td><td>334 PPH</td></tr><tr><td>12,000 ft</td><td>1400 ft-lb</td><td>308 PPH</td></tr><tr><td>16,000 ft</td><td>1335 ft-lb</td><td>284 PPH</td></tr><tr><td>22,000 ft</td><td>1175 ft-lb</td><td>256 PPH</td></tr></table><h3>Primary targets</h3><table><tr><td>ITT</td><td>Below 720 C</td></tr><tr><td>Ng</td><td>Below 99 percent</td></tr><tr><td>Propeller</td><td>1750 RPM</td></tr></table><p class="manual-note">Amphibian interpolation uses its corresponding variant table and terminates at 20,000 ft.</p></article><article class="manual-page" data-page="alerts"><h2>Alert logic</h2><h3>Starter</h3><p>Starter timing uses actual starter-motor activity rather than switch position. A warning appears at 35 seconds and ABORT at 40 seconds.</p><h3>Hot start</h3><p>HOT START applies when the turbine is actively turning below 12 percent Ng and the condition lever is moved out of CUTOFF. A cold engine at zero Ng does not trigger it.</p><h3>Propeller overspeed</h3><p>Above 1900 RPM for more than two seconds produces a live alert. More than 15 seconds logs a limit event. Above 2090 RPM for more than two seconds logs immediately.</p><h3>Fuel imbalance</h3><p>At 200 lb difference, the display advises selecting off the lower-fuel tank. At 250 lb difference, a critical event is logged.</p><h3>Oil pressure</h3><p>Post-ignition oil-pressure monitoring looks for a substantial unexpected drop while suppressing the expected pressure decay during normal shutdown.</p></article></section>';document.body.appendChild(manual);
  new window.KabochaNotebookController(notebookCubby,manual);
  var lampFiles={green:{unlit:'Assets/lamp-green-unlit.png',lit:'Assets/lamp-green-lit.png'},red:{unlit:'Assets/lamp-red-unlit.png',lit:'Assets/lamp-red-lit.png'}};
  function addPhotoLamp(host,color){if(!host||host.querySelector('.photo-lamp'))return;var base=document.createElement('img'),lit=document.createElement('img');base.className='photo-lamp unlit';base.src=lampFiles[color].unlit;base.alt='';lit.className='photo-lamp lit';lit.src=lampFiles[color].lit;lit.alt='';host.appendChild(base);host.appendChild(lit);}
  document.querySelectorAll('.start-item .state-lamp').forEach(function(lamp){addPhotoLamp(lamp,'green');});
  document.querySelectorAll('.monitor-module:first-child .instrument .label').forEach(function(label){var stack=document.createElement('span');stack.className='lamp-stack';label.appendChild(stack);addPhotoLamp(stack,'red');});
  var numericSegments={a:[10,8,42,8],b:[46,12,46,46],c:[46,54,46,88],d:[10,92,42,92],e:[6,54,6,88],f:[6,12,6,46],g:[10,50,42,50]};
  var numericMap={'0':'abcdef','1':'bc','2':'abdeg','3':'abcdg','4':'bcfg','5':'acdfg','6':'acdefg','7':'abc','8':'abcdefg','9':'abcdfg','-':'g'};
  var segmentMasks={itt:'888',torque:'8888',ng:'888.8',propRpm:'8888',oilPressure:'888',oilTemperature:'888',fuelPressure:'88.8',fuelFlow:'888',heading:'888',headingBug:'888',course:'888',oat:'888',fuelFlowRaw:'88.8'};
  function fitSegmentMask(value,mask){
    value=String(value||'').replace(/[^0-9.\-]/g,'');if(!mask)return value;
    if(mask.indexOf('.')<0)return value.slice(-mask.length).padStart(mask.length,' ');
    var dot=mask.indexOf('.'),integerWidth=dot,fractionWidth=mask.length-dot-1,parts=value.split('.');
    var integer=(parts[0]||'').slice(-integerWidth).padStart(integerWidth,' '),fraction=(parts[1]||'').slice(0,fractionWidth).padEnd(fractionWidth,'0');
    return integer+'.'+fraction;
  }
  function segmentNumber(host){
    if(!host||host.querySelector('svg.numeric-segment-char'))return;var value=(host.textContent||'').replace(/[^0-9.\-]/g,'');if(!value)return;var accessibleValue=value;
    value=fitSegmentMask(value,segmentMasks[host.id]);
    host.dataset.segmented='1';host.setAttribute('role','img');host.setAttribute('aria-label',accessibleValue);host.textContent='';host.classList.add('numeric-segment-display');var ns='http://www.w3.org/2000/svg';
    value.split('').forEach(function(ch){var svg=document.createElementNS(ns,'svg');svg.setAttribute('viewBox','0 0 52 100');svg.setAttribute('aria-hidden','true');svg.classList.add('numeric-segment-char');if(ch==='.'){svg.classList.add('segment-dot');var dot=document.createElementNS(ns,'circle');dot.setAttribute('cx','26');dot.setAttribute('cy','90');dot.setAttribute('r','4');dot.classList.add('on');svg.appendChild(dot);}else{var active=numericMap[ch]||'';Object.keys(numericSegments).forEach(function(name){var p=numericSegments[name],line=document.createElementNS(ns,'line');line.setAttribute('x1',p[0]);line.setAttribute('y1',p[1]);line.setAttribute('x2',p[2]);line.setAttribute('y2',p[3]);if(active.indexOf(name)>=0)line.classList.add('on');svg.appendChild(line);});}host.appendChild(svg);});
  }
  function segmentAllReadouts(){document.querySelectorAll('.monitor-module .readout>span,.navigation-rack .readout>span').forEach(segmentNumber);}
  segmentAllReadouts();setTimeout(segmentAllReadouts,0);
  document.querySelectorAll('.instrument,.start-item').forEach(function(group,index){var label=group.querySelector('.label,.start-name');if(!label)return;if(!label.id)label.id='instrument-label-'+index;group.setAttribute('role','group');group.setAttribute('aria-labelledby',label.id);});
  document.querySelectorAll('.monitor-module .readout>span,.navigation-rack .readout>span').forEach(function(host){
    new MutationObserver(function(){if(!host.querySelector('svg.numeric-segment-char'))segmentNumber(host);}).observe(host,{childList:true,characterData:true,subtree:true});
  });
  var alertPanel=document.querySelector('.alert-panel'),advisoryTitle=document.querySelector('.advisory-title');
  if(alertPanel&&advisoryTitle){var housing=document.createElement('div');housing.className='advisory-housing';advisoryTitle.parentNode.insertBefore(housing,advisoryTitle);housing.appendChild(advisoryTitle);housing.appendChild(alertPanel);}
  document.querySelectorAll('.start-rail,.advisory-housing,.monitor-module,.navigation-rack,.event-log').forEach(function(unit){
    unit.classList.add('hardware-mounted');
    ['tl','tr','bl','br'].forEach(function(c){var screw=document.createElement('i');screw.className='mount-screw '+c;unit.appendChild(screw);});
  });
});
</script>
'@
$notebookPages = Read-NotebookPages -Path (Join-Path $PSScriptRoot 'NOTEBOOK-CONTENT.md')
if ($notebookPages.Count -eq 0) { throw 'NOTEBOOK-CONTENT.md does not contain any page headings.' }

$tabs = New-Object Text.StringBuilder
$articles = New-Object Text.StringBuilder
$pageIndex = 0
foreach ($page in $notebookPages.GetEnumerator()) {
    $pageKey = [Net.WebUtility]::HtmlEncode($page.Key)
    $pageTitle = [Net.WebUtility]::HtmlEncode($page.Value.Title)
    $active = if ($pageIndex -eq 0) {' active'} else {''}
    [void]$tabs.Append('<button class="manual-tab' + $active + '" data-page="' + $pageKey + '">' + $pageTitle + '</button>')
    [void]$articles.Append('<article class="manual-page' + $active + '" data-page="' + $pageKey + '">' + $page.Value.Html + '</article>')
    $pageIndex++
}
$notebookMarkup = '<nav class="manual-tabs">' + $tabs + '</nav>' + $articles
$notebookPattern = '(?s)<nav class="manual-tabs">.*?</nav>(?:<article class="manual-page(?: active)?" data-page="[^"]+">.*?</article>)+'
if (-not [regex]::IsMatch($mock, $notebookPattern)) { throw 'Could not locate the notebook markup template.' }
$mock = [regex]::Replace($mock, $notebookPattern, $notebookMarkup, 1)
$html = $html.Replace('<script>', $mock + "`r`n<script>")
$html = $html.Replace('</body>', '<script src="WebRuntime/NotebookController.js"></script>' + "`r`n</body>")
Set-Content -LiteralPath $previewPath -Value $html -Encoding utf8
Write-Host "Created $previewPath"

$splitPreviewPath = Join-Path $PSScriptRoot 'Dashboard-Preview-Atmospheric-Split.html'
$splitCss = @'
<style>
body:has(main[data-theme="caravan-textured"]){padding:14px;background-size:cover,360px auto}
main[data-theme="caravan-textured"]{width:min(1740px,calc(100vw - 28px));margin:0 auto;padding:0;background:transparent;border:0;box-shadow:none}
main[data-theme="caravan-textured"] header{margin:0 0 14px;padding:10px 15px;background-color:#0b0d0c;background-image:linear-gradient(112deg,rgba(255,255,255,.028),transparent 35% 72%,rgba(0,0,0,.22)),url("Assets/avionics-body-wrinkle-black.png");background-repeat:no-repeat,repeat;background-position:center;background-size:cover,320px auto;border:1px solid #050607;box-shadow:inset 0 0 0 1px #343936,3px 5px 8px rgba(0,0,0,.58)}
main[data-theme="caravan-textured"] .dashboard-body{gap:16px}
main[data-theme="caravan-textured"] .rail-bank{gap:14px}
main[data-theme="caravan-textured"] .sequence-stack{gap:14px}
main[data-theme="caravan-textured"] .start-rail{margin:0;border:1px solid #050607;box-shadow:inset 0 0 0 1px #343936,3px 5px 8px rgba(0,0,0,.58)}
main[data-theme="caravan-textured"] .instrument-area{display:flex;flex-direction:column;gap:14px}
main[data-theme="caravan-textured"] .advisory-housing{margin:0;box-shadow:inset 0 0 0 1px #343936,3px 5px 8px rgba(0,0,0,.58)}
main[data-theme="caravan-textured"] .engine-rack{margin:0;padding:0;background:transparent;background-image:none;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .engine-grid{gap:14px}
main[data-theme="caravan-textured"] .monitor-module{border:1px solid #050607;box-shadow:inset 0 0 0 1px #343936,3px 5px 8px rgba(0,0,0,.58)}
main[data-theme="caravan-textured"] .navigation-rack{margin:0;border:1px solid #050607;box-shadow:inset 0 0 0 1px #343936,3px 5px 8px rgba(0,0,0,.58)}
main[data-theme="caravan-textured"] .event-log-stack{display:flex;flex-direction:column;gap:10px}
main[data-theme="caravan-textured"] .event-log-controls,main[data-theme="caravan-textured"] .event-log{margin:0;border:1px solid #050607;box-shadow:inset 0 0 0 1px #343936,3px 5px 8px rgba(0,0,0,.58)}
main[data-theme="caravan-textured"] .cruise-placard-wrap{left:20px;bottom:18px}
main[data-theme="caravan-textured"] header,main[data-theme="caravan-textured"] .start-rail,main[data-theme="caravan-textured"] .advisory-housing,main[data-theme="caravan-textured"] .monitor-module,main[data-theme="caravan-textured"] .navigation-rack,main[data-theme="caravan-textured"] .event-log-controls,main[data-theme="caravan-textured"] .event-log{border-radius:3px;outline:1px solid rgba(43,34,21,.82);box-shadow:inset 0 0 0 1px #343936,inset 0 0 10px rgba(0,0,0,.5),0 0 0 2px #776b4f,0 0 0 5px #b6a77e,0 0 0 7px rgba(73,59,35,.72),2px 5px 9px rgba(0,0,0,.72)}
main[data-theme="caravan-textured"] header{margin:8px 8px 22px}
main[data-theme="caravan-textured"] .dashboard-body{padding:8px;gap:26px}
main[data-theme="caravan-textured"] .rail-bank,main[data-theme="caravan-textured"] .sequence-stack,main[data-theme="caravan-textured"] .instrument-area{gap:24px}
main[data-theme="caravan-textured"] .engine-grid{gap:24px}
main[data-theme="caravan-textured"] .event-log-stack{gap:20px}
main[data-theme="caravan-textured"] .drag-module{cursor:grab;touch-action:none;user-select:none;will-change:transform;transition:filter .12s ease}
main[data-theme="caravan-textured"] .drag-module.dragging{z-index:50;cursor:grabbing;filter:brightness(1.06) drop-shadow(5px 9px 8px rgba(0,0,0,.65))}
.aircraft-placard-wrap.drag-module,.cruise-placard-wrap.drag-module{cursor:grab;touch-action:none;user-select:none;pointer-events:auto;will-change:transform}.aircraft-placard-wrap.dragging,.cruise-placard-wrap.dragging{z-index:60;cursor:grabbing}
.layout-tools{position:fixed;z-index:100;right:18px;bottom:18px;display:flex;align-items:center;gap:8px}.layout-export{height:30px;padding:0 12px;border:1px solid #090a09;border-radius:2px;background:linear-gradient(#555750,#252723 48%,#121310 52%,#31332e);box-shadow:0 0 0 1px #77776d,inset 0 1px rgba(255,255,255,.16),2px 4px 5px rgba(0,0,0,.65);color:#e4dfce;font:700 9px "Arial Narrow","Segoe UI",sans-serif;letter-spacing:.13em;cursor:pointer}.layout-export:active{transform:translate(1px,1px)}.layout-export-status{min-width:62px;color:#3b3020;font:700 9px Consolas,monospace;text-shadow:0 1px rgba(255,255,255,.35)}
</style>
'@
$splitHtml = $html.Replace('</head>', $splitCss + "`r`n</head>")
$splitDragScript = @'
<script>
document.addEventListener('DOMContentLoaded',function(){
  var storageKey='kabochaSplitModulePositionsV1';
  var saved={};
  try{saved=JSON.parse(localStorage.getItem(storageKey)||'{}');}catch(e){saved={};}
  var aircraftPlacard=document.querySelector('.aircraft-placard-wrap'),cruisePlacard=document.querySelector('.cruise-placard-wrap');
  if(aircraftPlacard)aircraftPlacard.dataset.layoutId='aircraft-placard';
  if(cruisePlacard)cruisePlacard.dataset.layoutId='kabocha-cruise-placard';
  var modules=document.querySelectorAll('#app>header,.start-rail,.advisory-housing,.monitor-module,.navigation-rack,.event-log-controls,.event-log,.aircraft-placard-wrap,.cruise-placard-wrap');
  modules.forEach(function(module,index){
    var key=module.dataset.layoutId||module.id||('module-'+index);
    module.classList.add('drag-module');
    module.dataset.dragKey=key;
    var pos=saved[key]||{x:0,y:0};
    var x=Number(pos.x)||0,y=Number(pos.y)||0;
    function apply(){module.style.transform='translate('+x+'px,'+y+'px)';}
    apply();
    module.addEventListener('pointerdown',function(event){
      if(event.button!==0||event.target.closest('button,input,select,a,[role="slider"]'))return;
      event.preventDefault();
      var startX=event.clientX,startY=event.clientY,baseX=x,baseY=y;
      module.classList.add('dragging');module.setPointerCapture(event.pointerId);
      function move(e){x=baseX+e.clientX-startX;y=baseY+e.clientY-startY;apply();}
      function end(e){module.classList.remove('dragging');module.releasePointerCapture(e.pointerId);saved[key]={x:Math.round(x),y:Math.round(y)};localStorage.setItem(storageKey,JSON.stringify(saved));module.removeEventListener('pointermove',move);module.removeEventListener('pointerup',end);module.removeEventListener('pointercancel',end);}
      module.addEventListener('pointermove',move);module.addEventListener('pointerup',end);module.addEventListener('pointercancel',end);
    });
    module.addEventListener('dblclick',function(event){if(event.target.closest('button,input,select,a,[role="slider"]'))return;x=0;y=0;apply();delete saved[key];localStorage.setItem(storageKey,JSON.stringify(saved));});
  });
  var tools=document.createElement('div'),button=document.createElement('button'),status=document.createElement('span');
  tools.className='layout-tools';button.className='layout-export';button.type='button';button.textContent='EXPORT LAYOUT';status.className='layout-export-status';tools.appendChild(button);tools.appendChild(status);document.body.appendChild(tools);
  button.addEventListener('click',function(){
    var output=JSON.stringify({preview:'Dashboard-Preview-Atmospheric-Split',positions:saved},null,2);
    function done(){status.textContent='COPIED';setTimeout(function(){status.textContent='';},1800);}
    if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(output).then(done).catch(function(){window.prompt('Copy layout coordinates:',output);});}
    else{window.prompt('Copy layout coordinates:',output);}
  });
});
</script>
'@
$splitHtml = $splitHtml.Replace('</body>', $splitDragScript + "`r`n</body>")
Set-Content -LiteralPath $splitPreviewPath -Value $splitHtml -Encoding utf8
Write-Host "Created $splitPreviewPath"

$skeuoPreviewPath = Join-Path $PSScriptRoot 'Dashboard-Preview-Skeuomorphic.html'
$skeuoCss = @'
<style>
body:has(main[data-theme="caravan-textured"]){padding:12px;background:#555344;background-image:radial-gradient(ellipse at 50% 30%,rgba(190,180,138,.25),rgba(19,18,14,.88) 82%),url("Assets/engine-rack-cream-pebble.png");background-size:cover,320px auto}
body .background-vignette{display:none}
main[data-theme="caravan-textured"]{width:min(1840px,calc(100vw - 24px));margin:0 auto;padding:13px 14px 16px;border:2px solid #070808;border-radius:8px;outline:1px solid #464943;background-color:#202322;background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent 31% 74%,rgba(0,0,0,.24)),url("Assets/avionics-body-wrinkle-black.png");background-repeat:no-repeat,repeat;background-size:cover,360px auto;box-shadow:inset 0 1px rgba(255,255,255,.11),inset 0 0 42px rgba(0,0,0,.58),0 13px 28px rgba(0,0,0,.75)}
main[data-theme="caravan-textured"] header{height:92px;margin:0 0 13px;padding:0 10px;background:transparent;background-image:none;border:0;box-shadow:none;align-items:start}
main[data-theme="caravan-textured"] .brand-logo{width:270px;margin-top:2px;padding:5px;border:2px solid #181918;border-radius:7px;background:#aaa69b;box-shadow:inset 0 0 0 2px #d4d0c5,inset 0 0 0 4px #5b5a55,2px 4px 6px rgba(0,0,0,.7);filter:grayscale(.65) contrast(.88) brightness(1.15)}
main[data-theme="caravan-textured"] .notebook-cubby{top:1px;width:330px;height:84px;border:5px solid #898983;border-radius:7px;box-shadow:inset 0 0 0 2px #d3d2cb,inset 0 7px 13px #000,2px 4px 6px rgba(0,0,0,.72)}
main[data-theme="caravan-textured"] .header-actions{padding-top:46px}
main[data-theme="caravan-textured"] .flight-data-window{border:2px solid #807b69;border-radius:3px;background:#10140d;box-shadow:inset 0 5px 10px #000,0 0 0 1px #24251f,1px 2px 3px #000}
main[data-theme="caravan-textured"] .power-button{background:linear-gradient(#9b7743,#5b4022 48%,#342313 53%,#76542c);border-color:#1a1008;box-shadow:0 0 0 2px #90734c,inset 0 1px #d7ba7c,2px 3px 4px #000;color:#f0d69a}
main[data-theme="caravan-textured"] .dashboard-body{grid-template-columns:420px minmax(0,1fr) 245px;gap:12px}
main[data-theme="caravan-textured"] .rail-bank{gap:10px}
main[data-theme="caravan-textured"] .sequence-stack{gap:10px}
main[data-theme="caravan-textured"] .start-rail{padding:9px 12px 12px;border:1px solid #090a09;border-radius:6px;background:#252827;background-image:linear-gradient(130deg,rgba(255,255,255,.035),transparent 42%),url("Assets/panel-texture-charcoal-seamless.png");background-size:cover,cover;box-shadow:inset 0 0 0 1px #454944,inset 0 4px 9px rgba(0,0,0,.56),2px 4px 6px rgba(0,0,0,.62)}
main[data-theme="caravan-textured"] .rail-title{padding:3px 3px 8px;text-align:left;font-size:11px;color:#ded9c8}
main[data-theme="caravan-textured"] .start-list{margin:0;padding:0;background:transparent;background-image:none;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .start-item{height:38px;min-height:38px;padding:3px 4px;background:transparent!important;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .start-item .state-lamp{left:2px;top:16%;width:23px;height:23px}
main[data-theme="caravan-textured"] .start-name{font-size:9px}
main[data-theme="caravan-textured"] .advisory-housing{margin:0;padding:9px 13px 12px;border:5px solid #858681;border-radius:6px;background:#8e8f8a;background-image:linear-gradient(110deg,#dadad3,#777874 45%,#b8b8b1);box-shadow:inset 0 0 0 2px #30322f,2px 4px 7px rgba(0,0,0,.7)}
main[data-theme="caravan-textured"] .advisory-housing .advisory-title{margin:0 0 6px;color:#161714;text-shadow:0 1px rgba(255,255,255,.35)}
main[data-theme="caravan-textured"] .advisory-housing .alert-panel{height:76px;min-height:76px;max-height:76px;border:2px solid #17120e;border-radius:3px;background-color:#250906;background-image:linear-gradient(120deg,rgba(255,255,255,.065),transparent 42%),repeating-linear-gradient(0deg,transparent 0 2px,rgba(255,77,38,.035) 2px 3px);box-shadow:inset 0 7px 14px #080100,inset 3px 0 6px rgba(0,0,0,.8),0 0 0 2px #4a4640;color:#ef5b3a}
main[data-theme="caravan-textured"] .instrument-area{gap:10px}
main[data-theme="caravan-textured"] .monitor-module,main[data-theme="caravan-textured"] .navigation-rack{border:1px solid #060706;border-radius:6px;background-color:#252827;background-image:linear-gradient(125deg,rgba(255,255,255,.035),transparent 37% 76%,rgba(0,0,0,.28)),url("Assets/panel-texture-charcoal-seamless.png");background-size:cover,cover;box-shadow:inset 0 0 0 1px #494d48,inset 0 5px 12px rgba(0,0,0,.58),2px 4px 7px rgba(0,0,0,.66)}
main[data-theme="caravan-textured"] .monitor-module{padding:13px 10px 9px}
main[data-theme="caravan-textured"] .monitor-module:first-child .instrument{min-height:129px}
main[data-theme="caravan-textured"] .monitor-module:nth-child(2) .instrument{min-height:87px}
main[data-theme="caravan-textured"] .instrument .readout{border:1px solid #080908;border-radius:7px;background:linear-gradient(145deg,#333837 0,#080a09 25%,#030404 72%,#171a18 100%);box-shadow:inset 0 8px 13px #000,inset 4px 0 6px rgba(0,0,0,.76),inset -2px -2px 3px rgba(116,126,116,.17),0 0 0 2px #414642,0 3px 5px rgba(0,0,0,.72)}
main[data-theme="caravan-textured"] .instrument .readout:after{content:"";position:absolute;inset:2px;border-radius:5px;background:linear-gradient(120deg,rgba(255,255,255,.075),transparent 38%);pointer-events:none}
main[data-theme="caravan-textured"] .monitor-module:first-child .instrument .limit{height:27px;min-height:27px;margin-top:7px;border-radius:4px;background:#13200f;box-shadow:inset 0 5px 9px #000,0 0 0 2px #343b31;color:#acd57b}
main[data-theme="caravan-textured"] .navigation-rack{padding:14px 16px 48px}
main[data-theme="caravan-textured"] .aux-grid{gap:12px}
main[data-theme="caravan-textured"] .aux-grid .instrument{position:relative;min-height:76px}
main[data-theme="caravan-textured"] .nav-knob{position:absolute;z-index:7;left:50%;bottom:-42px;width:43px;height:43px;transform:translateX(-50%);border:1px solid #080908;border-radius:50%;background:radial-gradient(circle at 38% 34%,#b7b7ad 0 5%,#777970 24%,#222522 27% 42%,#999b92 44% 47%,#343734 50% 65%,#111310 68%);box-shadow:inset 2px 2px 4px rgba(255,255,255,.24),inset -3px -4px 5px rgba(0,0,0,.72),2px 5px 6px rgba(0,0,0,.78)}
main[data-theme="caravan-textured"] .nav-knob:before{content:"";position:absolute;left:20px;top:4px;width:3px;height:13px;border-radius:2px;background:#e2e0d4;box-shadow:0 0 2px #fff}
main[data-theme="caravan-textured"] .event-log-controls{background:transparent;background-image:none;border:0;box-shadow:none}
main[data-theme="caravan-textured"] .event-log{border:1px solid #080908;border-radius:6px;background:#272a29;background-image:linear-gradient(130deg,rgba(255,255,255,.035),transparent),url("Assets/panel-texture-charcoal-seamless.png");background-size:cover,cover;box-shadow:inset 0 0 0 1px #4c504c,2px 4px 7px rgba(0,0,0,.68)}
main[data-theme="caravan-textured"] .log-screen{border-radius:3px;background:#071009;box-shadow:inset 0 8px 15px #000,0 0 0 2px #343a34}
main[data-theme="caravan-textured"] .safety-label{width:275px;left:22px;bottom:18px}

/* Second-pass skeuomorphic depth model: chassis > pocket > bezel > glass. */
main[data-theme="caravan-textured"]{
  background-color:#2d302f;
  background-image:radial-gradient(rgba(255,255,255,.035) .7px,transparent .8px),radial-gradient(rgba(255,255,255,.018) .7px,transparent .8px),linear-gradient(118deg,rgba(255,255,255,.055),transparent 29% 72%,rgba(0,0,0,.31)),url("Assets/avionics-body-wrinkle-black.png");
  background-size:4px 4px,4px 4px,cover,360px auto;
  background-position:0 0,2px 2px,center,center;
  border:3px solid #111312;
  outline:1px solid #555954;
  box-shadow:inset 0 2px 0 rgba(255,255,255,.12),inset 2px 0 0 rgba(255,255,255,.035),inset 0 -3px 0 rgba(0,0,0,.6),inset 0 0 46px rgba(0,0,0,.38),0 18px 34px rgba(0,0,0,.72)
}
main[data-theme="caravan-textured"] header{
  height:96px;padding:3px 12px 0;border-bottom:2px solid #171918;
  box-shadow:0 1px 0 rgba(255,255,255,.075)
}
main[data-theme="caravan-textured"] .brand-logo{
  width:292px;padding:0;border:0;background:transparent;
  filter:drop-shadow(0 3px 2px rgba(0,0,0,.8));box-shadow:none
}
main[data-theme="caravan-textured"] .notebook-cubby{
  border-color:#242725;outline:1px solid #595d59;
  box-shadow:inset 0 9px 15px #000,inset 4px 0 8px rgba(0,0,0,.72),inset -2px -2px 2px rgba(255,255,255,.12),0 2px 3px rgba(0,0,0,.74)
}
main[data-theme="caravan-textured"] .flight-data-window{
  padding:5px 9px;border:1px solid #0b0d0b;border-bottom-color:#55584f;
  box-shadow:inset 0 4px 7px #000,inset 2px 0 3px rgba(0,0,0,.75),0 1px 0 rgba(255,255,255,.08)
}
main[data-theme="caravan-textured"] .start-rail,
main[data-theme="caravan-textured"] .monitor-module,
main[data-theme="caravan-textured"] .navigation-rack,
main[data-theme="caravan-textured"] .event-log{
  border:1px solid #111312;border-bottom-color:#525651;
  box-shadow:inset 0 3px 7px rgba(0,0,0,.7),inset 1px 0 0 rgba(255,255,255,.04),0 3px 5px rgba(0,0,0,.48),0 1px 0 rgba(255,255,255,.055)
}
main[data-theme="caravan-textured"] .start-rail{padding:10px 12px 12px;background-size:cover,420px auto}
main[data-theme="caravan-textured"] .rail-title{
  margin:0 0 5px;padding:2px 5px 8px;border-bottom:1px solid #101211;
  box-shadow:0 1px 0 rgba(255,255,255,.075);letter-spacing:1.25px
}
main[data-theme="caravan-textured"] .start-item{
  position:relative;height:38px;min-height:38px;padding:3px 5px 3px 34px!important;
  border-bottom:1px solid rgba(0,0,0,.42)!important;
  box-shadow:0 1px 0 rgba(255,255,255,.035)!important
}
main[data-theme="caravan-textured"] .start-item:last-child{border-bottom:0!important;box-shadow:none!important}
main[data-theme="caravan-textured"] .start-item .state-lamp{left:3px;top:50%;transform:translateY(-50%)}
main[data-theme="caravan-textured"] .start-name{color:#d9d8cf;text-shadow:0 -1px #000;letter-spacing:.55px}
main[data-theme="caravan-textured"] .advisory-housing{
  padding:10px 12px 13px;border:1px solid #111312;border-bottom-color:#666964;
  background-color:#303332;background-image:linear-gradient(118deg,rgba(255,255,255,.07),transparent 32% 78%,rgba(0,0,0,.28)),url("Assets/avionics-body-wrinkle-black.png");background-size:cover,360px auto;
  box-shadow:inset 0 2px 0 rgba(255,255,255,.1),inset 0 -2px 0 rgba(0,0,0,.55),0 4px 7px rgba(0,0,0,.55)
}
main[data-theme="caravan-textured"] .advisory-housing .advisory-title{color:#d9d8cf;text-shadow:0 -1px #000;letter-spacing:1.2px}
main[data-theme="caravan-textured"] .advisory-housing .alert-panel{
  border:1px solid #090604;border-bottom-color:#5b4640;outline:2px solid #151716;
  box-shadow:inset 0 9px 16px #090100,inset 4px 0 7px rgba(0,0,0,.82),inset -2px -2px 3px rgba(177,91,67,.1),0 3px 5px rgba(0,0,0,.72)
}
main[data-theme="caravan-textured"] .monitor-module{padding:14px 12px 10px;background-size:cover,520px auto}
main[data-theme="caravan-textured"] .instrument .readout{
  border:1px solid #050605;outline:2px solid #292d2a;
  box-shadow:inset 0 9px 14px #000,inset 4px 0 7px rgba(0,0,0,.8),inset -2px -2px 3px rgba(146,156,146,.14),0 4px 6px rgba(0,0,0,.72)
}
main[data-theme="caravan-textured"] .instrument .readout:after{
  background:linear-gradient(137deg,rgba(255,255,255,.085),rgba(255,255,255,.018) 36%,transparent 43% 100%)
}
main[data-theme="caravan-textured"] .monitor-module:first-child .instrument .limit{
  border:1px solid #080b07;outline:1px solid #3e443a;
  box-shadow:inset 0 5px 9px #000,inset 2px 0 4px rgba(0,0,0,.65),0 2px 3px rgba(0,0,0,.56)
}
main[data-theme="caravan-textured"] .numeric-segment-display{
  gap:.065em;height:1.02em;filter:drop-shadow(0 0 2px rgba(242,92,54,.22))
}
main[data-theme="caravan-textured"] .numeric-segment-char{width:.6em;height:1.02em}
main[data-theme="caravan-textured"] .numeric-segment-char.segment-dot{width:.19em;transform:translateY(8px)}
main[data-theme="caravan-textured"] .numeric-segment-char line,
main[data-theme="caravan-textured"] .numeric-segment-char circle{
  stroke-width:7.4;stroke-linecap:round;opacity:.035
}
main[data-theme="caravan-textured"] .numeric-segment-char .on{
  opacity:.96;filter:drop-shadow(0 0 1.2px currentColor) drop-shadow(0 0 3px rgba(239,84,47,.24))
}
main[data-theme="caravan-textured"] .navigation-rack{padding:14px 16px 48px;background-size:cover,520px auto}
main[data-theme="caravan-textured"] .event-log{padding:10px;background-size:cover,390px auto}
main[data-theme="caravan-textured"] .log-screen{
  border:1px solid #050705;outline:2px solid #2b2f2b;
  box-shadow:inset 0 10px 18px #000,inset 4px 0 7px rgba(0,0,0,.76),0 4px 6px rgba(0,0,0,.66)
}
@media(min-width:1200px) and (max-height:1000px){main[data-theme="caravan-textured"]{zoom:.94}}
</style>
'@
$skeuoHtml = $html.Replace('</head>', $skeuoCss + "`r`n</head>")
$skeuoScript = @'
<script>
document.addEventListener('DOMContentLoaded',function(){
  document.querySelectorAll('.navigation-rack .instrument').forEach(function(card){var knob=document.createElement('i');knob.className='nav-knob';card.appendChild(knob);});
});
</script>
'@
$skeuoHtml = $skeuoHtml.Replace('</body>', $skeuoScript + "`r`n</body>")
Set-Content -LiteralPath $skeuoPreviewPath -Value $skeuoHtml -Encoding utf8
Write-Host "Created $skeuoPreviewPath"
