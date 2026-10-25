//
// DoomToon: starts DoomToon (Chocolate Doom on its own small system) once,
// from the original Toon 2 software. After Doom the Toon restarts and is back
// here. A copy of the ReToon setup app (RetoonApp.qml).
// The work is done by doomtoon.sh in this folder, which the "tsc" helper runs
// as root when "external-doomtoon" is written to /tmp/tsc.command.
//

import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

App {
	id: doomtoonApp

	property url tileUrl: "DoomtoonTile.qml"
	property url doomtoonScreenUrl: "DoomtoonScreen.qml"
	property url thumbnailIcon: "qrc:/tsc/refresh.png"

	// what doomtoon.sh last reported: idle, needed, ready, working, restarting, error
	property string setupState: "idle"
	property string setupText: ""
	property int setupStep: 0
	property int setupSteps: 6
	// when the start was asked for (ms), 0 = not waiting for it to begin
	property double installAsked: 0
	// the status file as last read, and as it was when the start was asked for
	property string lastStatus: ""
	property string staleStatus: ""

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: "DoomToon", thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, baseTileSolarWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", doomtoonScreenUrl, this, null, {lazyLoadScreen: true});
	}

	function writeFile(path, text) {
		var f = new XMLHttpRequest();
		f.open("PUT", "file://" + path);
		f.send(text);
	}

	// what: "check" or "install"
	function request(what) {
		if (what === "install") {
			setupState = "working";
			setupText = "Starting...";
			installAsked = Date.now();
			staleStatus = lastStatus;
		}
		// doomtoon.sh checks for itself too; both must agree
		writeFile("/tmp/doomtoon.board", isNxt ? "toon2" : "toon1");
		writeFile("/tmp/doomtoon.request", what);
		writeFile("/tmp/tsc.command", "external-doomtoon");
		statusTimer.start();
	}

	function readStatus() {
		var f = new XMLHttpRequest();
		f.onreadystatechange = function() {
			if (f.readyState !== XMLHttpRequest.DONE || !f.responseText)
				return;
			try {
				var s = JSON.parse(f.responseText);
				// The helper takes a few seconds to start the script; until
				// then the file still holds what it held before the button
				// was pressed (see RetoonApp.qml).
				if (installAsked > 0) {
					if (f.responseText === staleStatus && Date.now() - installAsked < 30000)
						return;
					installAsked = 0;
				}
				lastStatus = f.responseText;
				setupState = s.state;
				setupText = s.text;
				setupStep = s.step;
				setupSteps = s.steps;
			} catch (e) {
				// half-written: the next round reads it whole
			}
		}
		f.open("GET", "file:///tmp/doomtoon.status");
		f.send();
	}

	Timer {
		id: statusTimer
		interval: 2000
		repeat: true
		onTriggered: readStatus()
	}
}
