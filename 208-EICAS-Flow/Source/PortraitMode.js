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
    var button = event.target.closest("button[data-efb-view]");
    if (button) setView(button.getAttribute("data-efb-view"));
  });
  if (media.addEventListener) media.addEventListener("change", applyMode);
  else media.addListener(applyMode);
  setView(requestedView ? requestedView[1] : "start");
  applyMode();
})();
