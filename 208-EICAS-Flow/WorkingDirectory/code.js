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
const $=id=>document.getElementById(id);
let starterBegan=null,itt1090Began=null,propOverspeedBegan=null,propTransientBegan=null;
let cruiseCandidateBegan=null,cruiseExitBegan=null,cruiseActive=false;
let oilBaseline=null,oilBaselineBegan=null,oilBaselinePeak=0;
let limitEvents=[],activeLimitEvents={},dismissedLimitEvents={};
var firstRunNotice=$('firstRunNotice'); if(firstRunNotice){firstRunNotice.hidden=true;}
const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const hdg=v=>String(Math.round(((Number(v)%360)+360)%360)).padStart(3,'0')+'Â°';

let lastTailDisplay=null;
const tailSegments={
  a1:[10,7,28,7],a2:[32,7,50,7],b:[53,10,53,45],c:[53,55,53,90],
  d1:[32,93,50,93],d2:[10,93,28,93],e:[7,55,7,90],f:[7,10,7,45],
  g1:[10,50,28,50],g2:[32,50,50,50],h:[11,11,27,45],i:[30,10,30,45],
  j:[49,11,33,45],k:[49,89,33,55],l:[30,55,30,90],m:[11,89,27,55]
};
const tailMap={
  '0':'a1 a2 b c d1 d2 e f','1':'b c','2':'a1 a2 b g1 g2 e d1 d2',
  '3':'a1 a2 b c d1 d2 g1 g2','4':'f g1 g2 b c','5':'a1 a2 f g1 g2 c d1 d2',
  '6':'a1 a2 f e g1 g2 c d1 d2','7':'a1 a2 b c','8':'a1 a2 b c d1 d2 e f g1 g2',
  '9':'a1 a2 b c d1 d2 f g1 g2','A':'a1 a2 b c e f g1 g2',
  'B':'a1 a2 b c d1 d2 g1 g2 i l','C':'a1 a2 d1 d2 e f',
  'D':'a1 a2 b c d1 d2 e f i l','E':'a1 a2 d1 d2 e f g1 g2',
  'F':'a1 a2 e f g1 g2','G':'a1 a2 c d1 d2 e f g2',
  'H':'b c e f g1 g2','I':'a1 a2 d1 d2 i l','J':'b c d1 d2 e',
  'K':'e f g1 h k','L':'d1 d2 e f','M':'b c e f h j',
  'N':'b c e f h k','O':'a1 a2 b c d1 d2 e f','P':'a1 a2 b e f g1 g2',
  'Q':'a1 a2 b c d1 d2 e f k','R':'a1 a2 b e f g1 g2 k',
  'S':'a1 a2 f g1 g2 c d1 d2','T':'a1 a2 i l','U':'b c d1 d2 e f',
  'V':'e f m k','W':'b c e f m k','X':'h j k m','Y':'h j l',
  'Z':'a1 a2 j m d1 d2','-':'g1 g2',' ':''
};
function renderTail(value){
  value=(value||'--------').trim().toUpperCase()||'--------';
  if(value===lastTailDisplay)return;
  lastTailDisplay=value;
  const ns='http://www.w3.org/2000/svg',display=document.createElement('span');
  display.className='seg-display';
  for(var flowCharIndex=0;flowCharIndex<value.length;flowCharIndex++){const ch=value.charAt(flowCharIndex);
    const svg=document.createElementNS(ns,'svg');
    svg.setAttribute('viewBox','0 0 60 100');
    svg.setAttribute('aria-hidden','true');
    svg.classList.add('seg-char');
    const active=new Set((tailMap[ch]||tailMap[' ']).split(' ').filter(Boolean));
    for(const name in tailSegments){
      const p=tailSegments[name],line=document.createElementNS(ns,'line');
      line.setAttribute('x1',p[0]);line.setAttribute('y1',p[1]);line.setAttribute('x2',p[2]);line.setAttribute('y2',p[3]);
      if(active.has(name))line.classList.add('on');
      svg.appendChild(line);
    }
    display.appendChild(svg);
  }
  const tail=$('tailNumber');tail.textContent='';tail.appendChild(display);tail.title=value;
}
function setConnection(connected,message){
  const status=$('simStatus');
  status.className='sim-status '+(connected?'connected':'offline');
  status.title=message||(connected?'Simulator connected':'Simulator disconnected');
}

function eventTime(date){return date.toLocaleTimeString([],{hour12:false,hour:'2-digit',minute:'2-digit',second:'2-digit'})}
function eventKey(title){
  title=String(title||'EVENT').toUpperCase();
  if(title.includes('ITT'))return'ITT';
  if(title.includes('TORQUE'))return'TORQUE';
  if(title.includes('OIL PRESSURE'))return'OIL PRESSURE';
  if(title.includes('OIL TEMP'))return'OIL TEMPERATURE';
  if(title.includes('PROP'))return'PROPELLER';
  if(title.includes('NG'))return'NG';
  if(title.includes('STARTER')||title.includes('HUNG START')||title.includes('ABORT START'))return'STARTER';
  return title;
}
function renderLimitEvents(){
  const host=$('logEvents'),count=$('logCount');if(!host||!count)return;
  count.textContent=String(limitEvents.length).padStart(2,'0')+' EVENTS';host.textContent='';
  if(!limitEvents.length){const empty=document.createElement('div');empty.className='log-empty';empty.textContent='NO RECORDED LIMIT EVENTS';host.appendChild(empty);return}
  limitEvents.slice(0,7).forEach(e=>{
    const row=document.createElement('div');row.className='log-event'+(e.severity==='critical'?' critical':'');
    const tm=document.createElement('div');tm.className='log-time';
    const clock=document.createElement('span');clock.textContent=eventTime(e.started);
    const sev=document.createElement('span');sev.className='log-severity';sev.textContent=e.severity==='critical'?'LIMIT':'WARN';tm.appendChild(clock);tm.appendChild(sev);
    const name=document.createElement('div');name.className='log-name';name.textContent=e.title;
    const detail=document.createElement('div');detail.className='log-detail';detail.textContent=e.detail;
    const status=document.createElement('div');status.className='log-cleared';status.textContent=e.active?'ACTIVE':'CLEARED '+eventTime(e.cleared);
    row.appendChild(tm);row.appendChild(name);row.appendChild(detail);row.appendChild(status);host.appendChild(row);
  });
}
function recordSessionEvent(key,severity,title,detail,active){
  const now=new Date(),existing=activeLimitEvents[key];
  if(existing){existing.severity=severity;existing.title=title;existing.detail=detail;renderLimitEvents();return}
  const event={key,severity,title,detail,started:now,active:active!==false,cleared:active===false?now:null};
  limitEvents.unshift(event);if(limitEvents.length>20)limitEvents.length=20;
  if(event.active)activeLimitEvents[key]=event;renderLimitEvents();
}
function updateLimitEvents(alerts){
  const seen={};
  alerts.filter(a=>a.severity==='critical').forEach(a=>{const key=eventKey(a.title);seen[key]=true;if(!dismissedLimitEvents[key])recordSessionEvent(key,a.severity,a.title,a.detail,true)});
  Object.keys(activeLimitEvents).forEach(key=>{if(!seen[key]){const e=activeLimitEvents[key];e.active=false;e.cleared=new Date();delete activeLimitEvents[key]}});
  Object.keys(dismissedLimitEvents).forEach(key=>{if(!seen[key])delete dismissedLimitEvents[key]});
  renderLimitEvents();
}

function clearLastLimitEvent(){
  if(!limitEvents.length)return;
  const removed=limitEvents.shift();
  if(removed.active){dismissedLimitEvents[removed.key]=true;delete activeLimitEvents[removed.key]}
  renderLimitEvents();
}

function setCard(name,level,sub,pct,greenEnd,amberEnd){
  const card=$('card-'+name);
  card.classList.remove('warn','crit');
  if(level==='warning')card.classList.add('warn');
  if(level==='critical')card.classList.add('crit');
  const se=$('sub-'+name);if(se)se.textContent=sub||'';
  const be=$('bar-'+name);if(be&&Number.isFinite(pct)){
    be.style.setProperty('--fill',clamp(pct,0,100)+'%');
    be.style.setProperty('--green-end',clamp(greenEnd,0,100)+'%');
    be.style.setProperty('--amber-end',clamp(amberEnd,0,100)+'%');
  }
}
function setStart(name,state,value,target){
  const item=$('start-'+name);
  item.classList.remove('ready','pending','blocked');
  item.classList.add(state);
  $('start-'+name+'-value').textContent=value;
  const te=$('start-'+name+'-target');if(te&&target)te.textContent=target;
}
function renderStartLegacy(d){
  const selector=Math.round(Number(d.fuelSelector));
  const leftOpen=selector===1||selector===2;
  const rightOpen=selector===1||selector===3;
  const leftQty=Number(d.leftFuelQuantity),rightQty=Number(d.rightFuelQuantity);
  const fuelIn=Number(d.fuelCutoffHandle)<=80;
  const firewallIn=Number(d.firewallCutoffHandle)<60;
  const pump=Math.round(Number(d.fuelPumpSwitch));
  const condition=Math.round(Number(d.conditionLever));
  const ng=Number(d.ng);
  const active=d.starter||ng>5||condition>0;
  const state=(ok,danger)=>ok?'ready':danger?'blocked':'pending';

  setStart('covers',state(!d.engineCovers,d.engineCovers),d.engineCovers?'INSTALLED':'REMOVED');
  setStart('left',state(leftOpen&&leftQty>1,active),leftOpen?'ON':'OFF');
  setStart('right',state(rightOpen&&rightQty>1,active),rightOpen?'ON':'OFF');
  setStart('fuelcutoff',state(fuelIn,active),fuelIn?'PUSHED IN':'PULLED OUT');
  setStart('firewall',state(firewallIn,active),firewallIn?'PUSHED IN':'PULLED OUT');
  setStart('battery',state(d.batteryMaster,d.starter),d.batteryMaster?'ON':'OFF');
  setStart('voltage',state(Number(d.busVoltage)>=24,d.starter),Number(d.busVoltage).toFixed(1)+' V');

  const pumpReady=ng>=52?(pump===0||pump===1):pump===0;
  setStart('pump',state(pumpReady,d.starter&&pump!==0),pump===0?'ON':pump===1?'NORM':'OFF',ng>=52?'Normal after start':'On for battery start');

  const conditionText=condition===2?'HIGH IDLE':condition===1?'LOW IDLE':'CUTOFF';
  const conditionReady=ng<12?condition===0:condition===1||condition===2;
  const earlyFuel=ng<12&&condition>0;
  setStart('condition',state(conditionReady,earlyFuel),conditionText,ng<12?'Cutoff until Ng above 12%':'Low idle after Ng above 12%');

  let starterState='pending',starterTarget='Engage starter / stabilize above 12%';
  if(earlyFuel){starterState='blocked';starterTarget='Fuel introduced below 12% Ng'}
  else if(d.starter&&ng<12){starterTarget='Motoring / wait for Ng above 12%'}
  else if(ng>=12&&condition===0){starterTarget='Move condition lever to low idle'}
  else if(d.starter&&ng<52){starterTarget='Monitor start / wait for Ng above 52%'}
  else if(d.starter&&ng>=52){starterTarget='Disengage starter'}
  else if(!d.starter&&ng>=52){starterState='ready';starterTarget='Start complete'}
  setStart('starter',starterState,(d.starter?'START':'OFF')+' Â· '+ng.toFixed(1)+'%',starterTarget);
}
let startCycleActive=false,startComplete=false,shutdownBegan=null,sequenceStarterBegan=null;
let prePassed={},prePassedValue={},startPassed={};
function resetStartSequence(){
  startCycleActive=false;startComplete=false;shutdownBegan=null;sequenceStarterBegan=null;
  prePassed={};prePassedValue={};startPassed={};
  oilBaseline=null;oilBaselineBegan=null;oilBaselinePeak=0;
  propOverspeedBegan=null;propTransientBegan=null;
  cruiseCandidateBegan=null;cruiseExitBegan=null;cruiseActive=false;
}
function setRail(prefix,name,state,value,target){
  const item=$(prefix+'-'+name);
  const valueElement=$(prefix+'-'+name+'-value');
  if(!item||!valueElement){console.warn('Missing dashboard row: '+prefix+'-'+name);return}
  item.classList.remove('ready','pending','blocked','action-ready','time-warning','abort-action');item.classList.add(state);
  valueElement.textContent=value;
  const te=$(prefix+'-'+name+'-target');if(te&&target)te.textContent=target;
}
function renderStartTwoPhase(d){
  const now=Date.now(),selector=Math.round(Number(d.fuelSelector));
  const leftOpen=selector===1||selector===2,rightOpen=selector===1||selector===3;
  const leftQty=Number(d.leftFuelQuantity),rightQty=Number(d.rightFuelQuantity);
  const fuelIn=Number(d.fuelCutoffHandle)<=80,firewallIn=Number(d.firewallCutoffHandle)<60;
  const pump=Math.round(Number(d.fuelPumpSwitch)),condition=Math.round(Number(d.conditionLever));
  const ng=Number(d.ng),fuelFlow=Number(d.fuelFlow),busVoltage=Number(d.busVoltage);
  if(d.starter||ng>5)startCycleActive=true;
  const preNow={covers:!d.engineCovers,left:leftOpen&&leftQty>1,right:rightOpen&&rightQty>1,
    fuelcutoff:fuelIn,firewall:firewallIn,
    prop:Number(d.propLeverPosition)>=95,power:Number(d.powerLeverPosition)>=15&&Number(d.powerLeverPosition)<=35,
    inertial:!!d.inertialSeparator};
  const preValue={covers:d.engineCovers?'INSTALLED':'REMOVED',
    left:leftOpen?'OPEN':'CLOSED',
    right:rightOpen?'OPEN':'CLOSED',
    fuelcutoff:fuelIn?'PUSHED IN':'PULLED OUT',firewall:firewallIn?'PUSHED IN':'PULLED OUT',
    prop:Number(d.propLeverPosition).toFixed(0)+'%',power:Number(d.powerLeverPosition).toFixed(0)+'%',
    inertial:d.inertialSeparator?'OPEN':'CLOSED'};
  if(startCycleActive)Object.keys(preNow).forEach(k=>{if(preNow[k]&&!prePassed[k]){prePassed[k]=true;prePassedValue[k]=preValue[k]}});
  Object.keys(preNow).forEach(k=>{
    const latched=startCycleActive&&prePassed[k];
    setRail('pre',k,(preNow[k]||latched)?'ready':'blocked',latched?prePassedValue[k]:preValue[k]);
  });

  const batteryReady=!!d.batteryMaster&&busVoltage>=24,pumpOn=pump===0;
  if(startCycleActive&&batteryReady)startPassed.battery=true;
  if(startCycleActive&&pumpOn)startPassed.pump=true;
  if(ng>=12&&condition>0)startPassed.condition=true;
  if(ng>=52&&!d.starter&&fuelFlow>1){startComplete=true;startPassed.starter=true}
  const stopped=startCycleActive&&!d.starter&&ng<5&&fuelFlow<1;
  if(stopped){if(!shutdownBegan)shutdownBegan=now;else if(now-shutdownBegan>=3000)resetStartSequence()}
  else shutdownBegan=null;

  const batteryLatched=startCycleActive&&startPassed.battery;
  setRail('start','battery',(batteryReady||batteryLatched)?'ready':'blocked',batteryLatched&&!batteryReady?'PASSED':d.batteryMaster?'ON':'OFF');
  $('start-voltage-value').textContent='BUS '+busVoltage.toFixed(1)+' V';
  const pumpLatched=startCycleActive&&startPassed.pump;
  const pumpReady=startComplete?(pumpLatched||pump===1):pumpOn||pumpLatched;
  setRail('start','pump',pumpReady?'ready':d.starter?'blocked':'pending',pump===0?'ON':pump===1?'NORM':'OFF',startComplete?'Normal after start':'On for battery start');

  const conditionText=condition===2?'HIGH IDLE':condition===1?'LOW IDLE':'CUTOFF';
  const conditionReady=ng<12?condition===0:condition===1||condition===2;
  const earlyFuel=ng<12&&condition>0,conditionDone=startComplete&&startPassed.condition;
  setRail('start','condition',conditionDone||conditionReady?'ready':earlyFuel?'blocked':'pending',conditionDone?'PASSED':conditionText,conditionDone?'Fuel introduced above 12% Ng':ng<12?'Cutoff until Ng above 12%':'Low idle after Ng above 12%');
  let starterState='pending',starterTarget='Engage starter / stabilize above 12%';
  if(startComplete){starterState='ready';starterTarget='Start complete / sequence latched'}
  else if(earlyFuel){starterState='blocked';starterTarget='Fuel introduced below 12% Ng'}
  else if(d.starter&&ng<12)starterTarget='Motoring / wait for Ng above 12%';
  else if(ng>=12&&condition===0)starterTarget='Move condition lever to low idle';
  else if(d.starter&&ng<52)starterTarget='Monitor start / wait for Ng above 52%';
  else if(d.starter&&ng>=52)starterTarget='Disengage starter';
  setRail('start','starter',starterState,d.starter?'START':'OFF',starterTarget);
}
function renderStart(d){
  const now=Date.now(),selector=Math.round(Number(d.fuelSelector));
  const leftOpen=selector===1||selector===2,rightOpen=selector===1||selector===3;
  const leftQty=Number(d.leftFuelQuantity),rightQty=Number(d.rightFuelQuantity);
  const fuelIn=Number(d.fuelCutoffHandle)<=80,firewallIn=Number(d.firewallCutoffHandle)<60;
  const pump=Math.round(Number(d.fuelPumpSwitch)),condition=Math.round(Number(d.conditionLever));
  const ng=Number(d.ng),fuelFlow=Number(d.fuelFlow),busVoltage=Number(d.busVoltage),motorActive=!!d.starterActive;
  const cranking=motorActive||ng>5,justStarted=!startCycleActive&&cranking;
  if(motorActive){if(!sequenceStarterBegan)sequenceStarterBegan=now}else sequenceStarterBegan=null;
  if(cranking)startCycleActive=true;

  const preNow={covers:!d.engineCovers,left:leftOpen&&leftQty>1,right:rightOpen&&rightQty>1,
    fuelcutoff:fuelIn,firewall:firewallIn,
    prop:Number(d.propLeverPosition)>=95,power:Number(d.powerLeverPosition)>=15&&Number(d.powerLeverPosition)<=35,
    inertial:!!d.inertialSeparator};
  const preValue={covers:d.engineCovers?'INSTALLED':'REMOVED',
    left:leftOpen?'OPEN':'CLOSED',right:rightOpen?'OPEN':'CLOSED',
    fuelcutoff:fuelIn?'PUSHED IN':'PULLED OUT',firewall:firewallIn?'PUSHED IN':'PULLED OUT',
    prop:Number(d.propLeverPosition).toFixed(0)+'%',power:Number(d.powerLeverPosition).toFixed(0)+'%',inertial:d.inertialSeparator?'OPEN':'CLOSED'};
  if(startCycleActive)Object.keys(preNow).forEach(k=>{if(preNow[k]&&!prePassed[k]){prePassed[k]=true;prePassedValue[k]=preValue[k]}});
  Object.keys(preNow).forEach(k=>{const latched=startCycleActive&&prePassed[k];setRail('pre',k,(preNow[k]||latched)?'ready':'blocked',latched?prePassedValue[k]:preValue[k])});

  const batteryReady=!!d.batteryMaster&&busVoltage>=24,pumpOn=pump===0,conditionCutoff=condition===0;
  if(justStarted){
    if(batteryReady)startPassed.battery=true;
    if(pumpOn)startPassed.pump=true;
    if(conditionCutoff)startPassed.condition=true;
    startPassed.starter=true;
  }
  setRail('start','battery',(batteryReady||(startCycleActive&&startPassed.battery))?'ready':'blocked',startCycleActive&&startPassed.battery?'PASSED':d.batteryMaster?'ON':'OFF');
  $('start-voltage-value').textContent='BUS '+busVoltage.toFixed(1)+' V';
  setRail('start','pump',(pumpOn||(startCycleActive&&startPassed.pump))?'ready':'blocked',startCycleActive&&startPassed.pump?'PASSED':pump===0?'ON':pump===1?'NORM':'OFF','On before engaging starter');
  setRail('start','condition',(conditionCutoff||(startCycleActive&&startPassed.condition))?'ready':'blocked',startCycleActive&&startPassed.condition?'PASSED':condition===2?'HIGH IDLE':condition===1?'LOW IDLE':'CUTOFF','Cutoff before engaging starter');
  const allPreReady=Object.keys(preNow).every(k=>preNow[k]);
  const engageReady=!startCycleActive&&!d.starter&&ng<5&&allPreReady&&batteryReady&&pumpOn&&conditionCutoff;
  setRail('start','starter',startCycleActive&&startPassed.starter?'ready':engageReady?'action-ready':!d.starter&&ng<5?'pending':'blocked',startCycleActive&&startPassed.starter?'ENGAGED':engageReady?'ENGAGE':d.starter?'START':'OFF',startCycleActive?'Start permission captured':engageReady?'Engage starter now':'Complete all permissives');

  if(!startCycleActive){
    setRail('seq','condition','pending','WAIT','Low idle above 12% Ng');
    setRail('seq','starter','pending','WAIT','Off at 52% Ng');
    setRail('seq','pump','pending','WAIT','Normal after starter off');
    setRail('seq','ready','pending','NOT READY','Engage starter to begin');
  }else{
    const earlyFuel=ng<12&&condition>0;
    if(ng>=12&&condition>0)startPassed.seqCondition=true;
    const conditionDone=!!startPassed.seqCondition;
    const moveCondition=ng>=12&&!conditionDone&&condition===0;
    setRail('seq','condition',conditionDone?'ready':earlyFuel?'blocked':moveCondition?'action-ready':'pending',conditionDone?(condition===2?'HIGH IDLE':'LOW IDLE'):earlyFuel?'TOO EARLY':moveCondition?'MOVE TO LOW IDLE':condition===2?'HIGH IDLE':condition===1?'LOW IDLE':'CUTOFF',conditionDone?'Fuel introduced above 12% Ng':moveCondition?'Move condition lever now':'Hold cutoff until 12% Ng');

    if(ng>=52&&!d.starter)startPassed.seqStarter=true;
    const starterDone=!!startPassed.seqStarter;
    const turnStarterOff=ng>=52&&!starterDone&&d.starter;
    const starterSeconds=sequenceStarterBegan?(now-sequenceStarterBegan)/1000:0;
    const abortStart=motorActive&&ng<52&&starterSeconds>=30;
    setRail('seq','starter',starterDone?'ready':turnStarterOff?'action-ready':abortStart?'abort-action':!motorActive&&ng<52?'pending':'pending',starterDone?'OFF':turnStarterOff?'TURN OFF':abortStart?'ABORT START':motorActive?'MOTOR ON':d.starter?'START SELECTED':'OFF',starterDone?'Starter switch off confirmed':turnStarterOff?'Motor stopped - move switch off':abortStart?'30 second motor limit - abort start':motorActive?'Starter motor running':'Motor disengaged / monitor Ng');

    if(starterDone&&pump===1)startPassed.seqPump=true;
    const pumpDone=!!startPassed.seqPump;
    const setPumpNormal=starterDone&&!pumpDone&&pump!==1;
    setRail('seq','pump',pumpDone?'ready':setPumpNormal?'action-ready':pump!==0&&!starterDone?'blocked':'pending',pumpDone?'NORM':setPumpNormal?'SET TO NORMAL':pump===0?'ON':pump===1?'NORM':'OFF',pumpDone?'After-start position confirmed':setPumpNormal?'Set boost pump to NORM now':'Hold ON until starter is off');

    startComplete=conditionDone&&starterDone&&pumpDone&&ng>=52&&fuelFlow>1;
    setRail('seq','ready',startComplete?'ready':'pending',startComplete?'FLIGHT READY':'NOT READY',startComplete?'Start sequence complete':'Complete the highlighted actions');
  }

  const stopped=startCycleActive&&!d.starter&&ng<5&&fuelFlow<1;
  if(stopped){if(!shutdownBegan)shutdownBegan=now;else if(now-shutdownBegan>=3000)resetStartSequence()}
  else shutdownBegan=null;
}
function pushAlert(a,severity,title,detail){a.push({severity,title,detail})}
function phaseOf(d){
  if(d.starterActive||(d.ng>0&&d.ng<52&&d.fuelFlow>0))return'STARTING';
  if(d.onGround){cruiseCandidateBegan=null;cruiseExitBegan=null;cruiseActive=false;return'TAKEOFF'}
  const now=Date.now(),stable=Math.abs(Number(d.verticalSpeed))<=100;
  if(stable){
    cruiseExitBegan=null;
    if(!cruiseCandidateBegan)cruiseCandidateBegan=now;
    if(now-cruiseCandidateBegan>=5000)cruiseActive=true;
  }else{
    cruiseCandidateBegan=null;
    if(cruiseActive){
      if(!cruiseExitBegan)cruiseExitBegan=now;
      if(now-cruiseExitBegan>=2000){cruiseActive=false;cruiseExitBegan=null}
    }
  }
  return cruiseActive?'CRUISE':'CLIMB';
}
function ngLimit(oat){return oat>=-30?101.6:101.6-Math.floor((-30-oat)/10)*2.2}
function normalCruiseGuide(pressureAltitude,aircraftTitle){
  const amphib=String(aircraftTitle||'').toUpperCase().includes('AMPHIB');
  const points=amphib?[[4000,1600,365],[8000,1500,334],[12000,1400,308],[16000,1335,284],[20000,1185,265]]:[[4000,1600,365],[8000,1500,334],[12000,1400,308],[16000,1335,284],[22000,1175,256]];
  const altitude=Number(pressureAltitude);
  if(altitude<=points[0][0])return{torque:points[0][1],fuel:points[0][2],altitude:points[0][0],clamped:true};
  const last=points[points.length-1];
  if(altitude>=last[0])return{torque:last[1],fuel:last[2],altitude:last[0],clamped:true};
  for(let i=1;i<points.length;i++)if(altitude<=points[i][0]){
    const low=points[i-1],high=points[i],ratio=(altitude-low[0])/(high[0]-low[0]);
    return{torque:Math.round((low[1]+(high[1]-low[1])*ratio)/5)*5,fuel:Math.round(low[2]+(high[2]-low[2])*ratio),altitude:Math.round(altitude),clamped:false};
  }
  return{torque:last[1],fuel:last[2],altitude:last[0],clamped:true};
}
function analyze(d){
  const alerts=[],phase=phaseOf(d),now=Date.now();
  let iw=740,ic=765,imax=805,il='MAX 765 C';
  if(phase==='STARTING'){iw=805;ic=1090;imax=1120;il='MAX 1090 C / 2 SEC'}
  else if(phase==='TAKEOFF'){iw=765;ic=805;imax=850;il='MAX 805 C'}
  else if(phase==='CRUISE'){iw=740;ic=765;il='GUIDE <720 Â· LIMIT 740 C'}
  let ittLevel=d.itt>=ic?'critical':d.itt>=iw?'warning':'normal';
  if(phase==='STARTING'&&d.itt>=1090){
    if(!itt1090Began)itt1090Began=now;
    const sec=(now-itt1090Began)/1000;
    pushAlert(alerts,sec>=2?'critical':'warning','START ITT',d.itt.toFixed(0)+' C / '+sec.toFixed(1)+' SEC');
  }else{
    itt1090Began=null;
    if(ittLevel==='critical')pushAlert(alerts,'critical','ITT LIMIT',d.itt.toFixed(0)+' C / '+il);
    else if(ittLevel==='warning')pushAlert(alerts,'warning','HIGH ITT',d.itt.toFixed(0)+' C / '+il);
  }
  if(d.onGround&&!d.starterActive&&d.ng<5&&d.itt>150)pushAlert(alerts,'warning','HOT RESTART','ITT '+d.itt.toFixed(0)+' C / DRY MOTOR RECOMMENDED');
  const conditionPosition=Math.round(Number(d.conditionLever));
  if(conditionPosition>0&&Number(d.ng)>0.5&&Number(d.ng)<12){
    const conditionText=conditionPosition===2?'HIGH IDLE':'LOW IDLE';
    pushAlert(alerts,'critical','HOT START',conditionText+' / NG '+Number(d.ng).toFixed(1)+'%');
  }

  let tqLevel=d.torque>1970?'critical':d.torque>1865?'warning':'normal';
  if(d.torque>2400)pushAlert(alerts,'critical','TORQUE TRANSIENT',d.torque.toFixed(0)+' FT-LB');
  else if(d.torque>1970)pushAlert(alerts,'critical','TORQUE LIMIT',d.torque.toFixed(0)+' FT-LB');
  else if(d.torque>1865)pushAlert(alerts,'warning','HIGH TORQUE',d.torque.toFixed(0)+' FT-LB');

  const nl=ngLimit(d.oat);
  let ngLevel=d.ng>102.6?'critical':d.ng>nl?'warning':'normal';
  if(d.ng>102.6)pushAlert(alerts,'critical','NG TRANSIENT',d.ng.toFixed(1)+'%');
  else if(d.ng>nl)pushAlert(alerts,'warning','NG LIMIT',d.ng.toFixed(1)+'% / LIMIT '+nl.toFixed(1)+'%');

  let propLevel='normal';
  if(d.propRpm>1900){
    if(!propOverspeedBegan)propOverspeedBegan=now;
    const propSeconds=(now-propOverspeedBegan)/1000;
    let transientSeconds=0;
    if(d.propRpm>2090){if(!propTransientBegan)propTransientBegan=now;transientSeconds=(now-propTransientBegan)/1000}
    else propTransientBegan=null;
    if(transientSeconds>2){
      propLevel='critical';
      pushAlert(alerts,'critical','PROP TRANSIENT',d.propRpm.toFixed(0)+' RPM / '+transientSeconds.toFixed(1)+' SEC ABOVE 2090');
    }else if(propSeconds>15){
      propLevel='critical';
      pushAlert(alerts,'critical','PROP OVERSPEED LIMIT',d.propRpm.toFixed(0)+' RPM / '+propSeconds.toFixed(1)+' SEC ABOVE 1900');
    }else if(propSeconds>2){
      propLevel='warning';
      pushAlert(alerts,'warning','PROP OVERSPEED',d.propRpm.toFixed(0)+' RPM / '+propSeconds.toFixed(1)+' SEC ABOVE 1900');
    }
  }else{propOverspeedBegan=null;propTransientBegan=null}

  let op='normal',opd='Baseline captures 5 sec after 52% Ng';
  const oilPressure=Number(d.oilPressure),oilNg=Number(d.ng);
  if(oilNg>=52&&oilPressure>0){
    if(!oilBaselineBegan){oilBaselineBegan=now;oilBaselinePeak=oilPressure}
    oilBaselinePeak=Math.max(oilBaselinePeak,oilPressure);
    if(oilBaseline===null&&now-oilBaselineBegan>=5000)oilBaseline=oilBaselinePeak;
  }
  const intentionalGroundShutdown=!!d.onGround&&Math.round(Number(d.conditionLever))===0&&!d.starterActive;
  if(oilBaseline!==null&&oilBaseline>0){
    const oilDrop=(oilBaseline-oilPressure)/oilBaseline*100;
    opd=intentionalGroundShutdown?'Shutdown Â· pressure decay expected':'Post-start baseline '+oilBaseline.toFixed(0)+' PSI';
    if(oilDrop>=40&&!intentionalGroundShutdown){
      op='critical';
      pushAlert(alerts,'critical','OIL PRESSURE DROP',oilPressure.toFixed(0)+' PSI / '+oilDrop.toFixed(0)+'% BELOW BASELINE');
    }
  }
  if(oilPressure>105){op='critical';pushAlert(alerts,'critical','HIGH OIL PRESSURE',oilPressure.toFixed(0)+' PSI')}
  let ot=d.oilTemperature>=104?'critical':d.oilTemperature>99?'warning':'normal';
  if(d.oilTemperature>=104)pushAlert(alerts,'critical','OIL TEMPERATURE',d.oilTemperature.toFixed(0)+' C');
  else if(d.oilTemperature>99)pushAlert(alerts,'warning','HIGH OIL TEMP',d.oilTemperature.toFixed(0)+' C');

  if(d.starterActive){
    if(!starterBegan)starterBegan=now;
    const sec=(now-starterBegan)/1000;
    if(sec>=30)pushAlert(alerts,'critical','STARTER LIMIT',sec.toFixed(0)+' SEC / ABORT START');
    if(d.fuelFlow>0&&d.ng<52&&sec>=30)pushAlert(alerts,'critical','POSSIBLE HUNG START','NG '+d.ng.toFixed(1)+'%');
  }else starterBegan=null;

  const fuelWeight=Number(d.fuelWeightPerGallon);
  if(fuelWeight>0){
    const leftPounds=Number(d.leftFuelQuantity)*fuelWeight,rightPounds=Number(d.rightFuelQuantity)*fuelWeight;
    const difference=Math.abs(leftPounds-rightPounds);
    if(difference>=200){
      const lowerLeft=leftPounds<rightPounds,selector=Math.round(Number(d.fuelSelector));
      const lowerOpen=lowerLeft?(selector===1||selector===2):(selector===1||selector===3);
      const lowerTank=lowerLeft?'LEFT':'RIGHT';
      const action=lowerOpen?'CLOSE '+lowerTank+' TANK':lowerTank+' TANK CLOSED';
      pushAlert(alerts,difference>=250?'critical':'warning','FUEL IMBALANCE',difference.toFixed(0)+' LB / '+action);
    }
  }
  return{alerts,phase,ittLevel,tqLevel,ngLevel,propLevel,op,ot,il,nl,opd,iw,ic,imax};
}
function render(d){
  renderStart(d);
  renderTail((d.tailNumber&&d.tailNumber.trim())?d.tailNumber.trim():'--------');
  $('itt').textContent=Number(d.itt).toFixed(0);
  $('torque').textContent=Number(d.torque).toFixed(0);
  $('ng').textContent=Number(d.ng).toFixed(1);
  $('propRpm').textContent=Number(d.propRpm).toFixed(0);
  $('oilPressure').textContent=Number(d.oilPressure).toFixed(0);
  $('oilTemperature').textContent=Number(d.oilTemperature).toFixed(0);
  $('fuelPressure').textContent=Number(d.fuelPressure).toFixed(1);
  $('fuelFlow').textContent=Number(d.fuelFlow).toFixed(0);
  $('fuelFlowRaw').textContent=(Number(d.fuelFlow)/6.7).toFixed(1);
  $('oat').textContent=Number(d.oat).toFixed(0);
  $('heading').textContent=hdg(Number(d.heading)*3.6);
  $('headingBug').textContent=hdg(d.headingBug);
  $('course').textContent=hdg(d.course);

  const a=analyze(d);
  updateLimitEvents(a.alerts);
  const cruiseGuide=a.phase==='CRUISE'?normalCruiseGuide(d.pressureAltitude,d.aircraftTitle):null;
  const ittText=a.phase==='CRUISE'?'GUIDE <720 Â· LIMIT 740 C':a.il;
  const torqueText=cruiseGuide?'GUIDE '+cruiseGuide.torque+' Â· LIMIT 1865 FT-LB':'MAX 1865 FT-LB';
  const ngText=a.phase==='CRUISE'?'GUIDE <99 Â· LIMIT '+a.nl.toFixed(1)+'%':'MAX '+a.nl.toFixed(1)+'%';
  const propText=a.phase==='CRUISE'?'GUIDE 1750 Â· LIMIT 1900 RPM':'MAX 1900 Â· 2090 / 2 SEC';
  setCard('itt',a.ittLevel,ittText,d.itt/a.imax*100,a.iw/a.imax*100,a.ic/a.imax*100);
  setCard('torque',a.tqLevel,torqueText,d.torque/2400*100,1865/2400*100,1970/2400*100);
  setCard('ng',a.ngLevel,ngText,d.ng/105*100,a.nl/105*100,102.6/105*100);
  setCard('prop',a.propLevel,propText,d.propRpm/2200*100,1900/2200*100,2090/2200*100);
  setCard('oilp',a.op,a.opd,d.oilPressure/120*100,100/120*100,105/120*100);
  setCard('oilt',a.ot,'99 CONTINUOUS / 104 TRANSIENT',d.oilTemperature/110*100,99/110*100,104/110*100);
  $('sub-fuelflow').textContent=cruiseGuide?'GUIDE '+cruiseGuide.fuel+' PPH Â· ISA Â· '+Math.round(Number(d.pressureAltitude))+' FT PA':'';

  const p=$('alertPanel'),t=$('alertTitle'),l=$('alertList');
  l.innerHTML='';
  const worst=a.alerts.some(x=>x.severity==='critical')?'critical':a.alerts.length?'warning':'clear';
  p.className='alert-panel '+worst;
  t.textContent=worst==='critical'?'WARNING - ENGINE LIMIT':worst==='warning'?'CAUTION - CHECK ENGINE':'ENGINE PARAMETERS NORMAL';
  a.alerts.forEach(x=>{const e=document.createElement('div');e.className='alert';const logged=x.severity==='critical'?' - EVENT LOGGED':'';e.innerHTML='<strong>'+x.title+logged+'</strong>'+x.detail;l.appendChild(e)});
}
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

const displayDimmer=$('displayDimmer');
let displayBrightness=Math.max(25,Math.min(100,Number(localStorage.getItem('kabochaDisplayBrightness'))||100));
function setDisplayBrightness(value){
  displayBrightness=Math.max(25,Math.min(100,Math.round(value)));
  document.documentElement.style.setProperty('--display-level',(displayBrightness/100).toFixed(2));
  displayDimmer.style.transform='rotate('+(-135+(displayBrightness-25)/75*270)+'deg)';
  displayDimmer.setAttribute('aria-valuenow',displayBrightness);
  displayDimmer.title='Display brightness '+displayBrightness+'% - drag, scroll, or use arrow keys';
  localStorage.setItem('kabochaDisplayBrightness',String(displayBrightness));
}
function brightnessFromPointer(event){
  const box=displayDimmer.getBoundingClientRect(),cx=box.left+box.width/2,cy=box.top+box.height/2;
  let angle=Math.atan2(event.clientY-cy,event.clientX-cx)*180/Math.PI+90;
  if(angle>180)angle-=360;
  angle=Math.max(-135,Math.min(135,angle));
  setDisplayBrightness(25+(angle+135)/270*75);
}
displayDimmer.addEventListener('pointerdown',event=>{displayDimmer.setPointerCapture(event.pointerId);brightnessFromPointer(event)});
displayDimmer.addEventListener('pointermove',event=>{if(displayDimmer.hasPointerCapture(event.pointerId))brightnessFromPointer(event)});
displayDimmer.addEventListener('wheel',event=>{event.preventDefault();setDisplayBrightness(displayBrightness+(event.deltaY<0?5:-5))},{passive:false});
displayDimmer.addEventListener('keydown',event=>{
  if(event.key==='ArrowRight'||event.key==='ArrowUp'){event.preventDefault();setDisplayBrightness(displayBrightness+5)}
  if(event.key==='ArrowLeft'||event.key==='ArrowDown'){event.preventDefault();setDisplayBrightness(displayBrightness-5)}
  if(event.key==='Home'){event.preventDefault();setDisplayBrightness(25)}
  if(event.key==='End'){event.preventDefault();setDisplayBrightness(100)}
});
$('clearLastEvent').addEventListener('click',clearLastLimitEvent);
const powerButton=$('powerButton');
if(powerButton){
  powerButton.title='Close 208 EICAS';
  powerButton.addEventListener('click',function(){
    if(flowRoot){flowRoot.classList.add('flow-widget-hidden');}
    var app=$('app');if(app){app.classList.add('flow-hidden');}
  });
}
setDisplayBrightness(displayBrightness);
refresh(); flowRefreshTimer=setInterval(refresh,100);
(function () {
  "use strict";
  var media = window.matchMedia("(max-width:899px)");
  var body = document.body;
  var requestedView = /(?:\?|&)view=(start|monitors|log)(?:&|$)/.exec(window.location.search);
  var tabs = document.getElementById("efbPortraitTabs");
  var host = document.getElementById("efbPortraitAdvisory");
  var instrumentArea = document.querySelector(".instrument-area");
  var engineRack = document.querySelector(".engine-rack");
  var advisoryTitle = document.querySelector(".advisory-title");
  var alertPanel = document.getElementById("alertPanel");

  function setView(view) {
    body.setAttribute("data-efb-view", view);
    var buttons = tabs.querySelectorAll("button");
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].classList.toggle("active", buttons[i].getAttribute("data-efb-view") === view);
    }
  }

  function applyMode() {
    if (media.matches) {
      if (advisoryTitle.parentNode !== host) {
        host.appendChild(advisoryTitle);
        host.appendChild(alertPanel);
      }
      if (!body.getAttribute("data-efb-view")) setView("start");
    } else {
      if (advisoryTitle.parentNode !== instrumentArea) {
        instrumentArea.insertBefore(alertPanel, engineRack);
        instrumentArea.insertBefore(advisoryTitle, alertPanel);
      }
    }
  }

  tabs.addEventListener("click", function (event) {
    var button=event.target;while(button&&button!==tabs&&!button.getAttribute('data-efb-view'))button=button.parentNode;if(button===tabs)button=null;
    if (button) setView(button.getAttribute("data-efb-view"));
  });
  if (media.addEventListener) media.addEventListener("change", applyMode);
  else media.addListener(applyMode);
  setView(requestedView ? requestedView[1] : "start");
  applyMode();
})();
});

exit(function() {
  if(flowRefreshTimer){clearInterval(flowRefreshTimer);flowRefreshTimer=null;}
  window.fetch=originalFetch;
});
