//
// DoomToon start screen: dark, Doom-red, one big button that puts DoomToon
// in place (the first time) and restarts the Toon into Doom, once.
//

import QtQuick 2.1
import qb.components 1.0

Screen {
	id: doomtoonScreen

	screenTitle: "DoomToon"

	property bool busy: app.setupState === "working" || app.setupState === "restarting"
	property bool canStart: isNxt && !busy &&
		(app.setupState === "ready" || app.setupState === "needed" || app.setupState === "error")

	onShown: if (isNxt) app.request("check")

	Image {
		anchors.fill: parent
		source: "drawables/background.png"
		fillMode: Image.PreserveAspectCrop
		clip: true
	}

	Text {
		id: headline
		anchors {
			top: parent.top
			topMargin: isNxt ? 30 : 24
			left: parent.left
			leftMargin: isNxt ? 60 : 48
			right: parent.right
			rightMargin: anchors.leftMargin
		}
		font {
			family: qfont.bold.name
			pixelSize: isNxt ? 40 : 30
		}
		color: "#e0301e"
		wrapMode: Text.WordWrap
		text: isNxt ? "Rip and tear, on your thermostat." : "DoomToon needs a Toon 2."
	}

	Text {
		id: intro
		visible: isNxt
		anchors {
			top: headline.bottom
			topMargin: isNxt ? 18 : 14
			left: headline.left
			right: headline.right
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 21 : 17
		}
		lineHeight: 1.15
		color: "#e4dccd"
		wrapMode: Text.WordWrap
		text: "The 1993 shareware episode of Doom, with its sound effects on the Toon's own beeper, " +
		      "played with a Bluetooth game pad (PlayStation, Xbox, 8BitDo, Switch Pro).\n\n" +
		      "Press the button and the Toon restarts into Doom. Pair your controller on the first screen, " +
		      "then play. To stop, choose Quit Game in Doom's menu or hold a finger on the screen for " +
		      "three seconds: the Toon restarts back here, just as you left it. " +
		      "While Doom runs, this Toon does not control the heating."
	}

	Rectangle {
		id: goButton
		visible: isNxt
		width: isNxt ? 300 : 240
		height: isNxt ? 64 : 50
		radius: 6
		anchors {
			top: intro.bottom
			topMargin: isNxt ? 28 : 22
			left: headline.left
		}
		color: !doomtoonScreen.canStart ? "#4a3c38" : (goArea.pressed ? "#8a160e" : "#b81e12")
		border.color: doomtoonScreen.canStart ? "#ff5a3c" : "#6a5a54"
		border.width: 2

		Text {
			anchors.centerIn: parent
			text: doomtoonScreen.busy ? "PLEASE WAIT..." : "START DOOM"
			color: doomtoonScreen.canStart ? "#ffffff" : "#a89890"
			font {
				family: qfont.bold.name
				pixelSize: isNxt ? 28 : 22
			}
		}

		MouseArea {
			id: goArea
			anchors.fill: parent
			enabled: doomtoonScreen.canStart
			onClicked: app.request("install")
		}
	}

	Text {
		id: statusLine
		visible: isNxt
		anchors {
			verticalCenter: goButton.verticalCenter
			left: goButton.right
			leftMargin: isNxt ? 30 : 24
			right: headline.right
		}
		font {
			family: qfont.semiBold.name
			pixelSize: isNxt ? 20 : 16
		}
		color: app.setupState === "error" ? "#ff7a5c" : "#cfc5b4"
		wrapMode: Text.WordWrap
		text: app.setupText === "" ? "Looking at what is on this Toon..." :
		      (doomtoonScreen.busy && app.setupStep > 0 ? "Step " + app.setupStep + " of " + app.setupSteps + ": " : "") + app.setupText
	}
}
