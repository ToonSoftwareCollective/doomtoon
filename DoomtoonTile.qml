//
// DoomToon tile: the DOOM picture; opens the start screen. In the dimmed
// (night) state only the word, in the dimmed colour.
//

import QtQuick 2.1
import qb.components 1.0

Tile {
	id: doomtoonTile
	property bool dimState: screenStateController.dimmedColors

	onClicked: stage.openFullscreen(app.doomtoonScreenUrl)

	Image {
		anchors.fill: parent
		source: "drawables/tile.png"
		fillMode: Image.PreserveAspectCrop
		clip: true
		visible: !dimState
	}

	Text {
		text: "DOOM"
		visible: dimState
		color: dimmableColors.clockTileColor
		anchors.centerIn: parent
		font.pixelSize: isNxt ? 48 : 36
		font.family: qfont.bold.name
	}

	Text {
		text: "tap to play"
		color: "#d8cfc0"
		visible: !dimState
		anchors {
			bottom: parent.bottom
			bottomMargin: isNxt ? 14 : 10
			horizontalCenter: parent.horizontalCenter
		}
		font.pixelSize: isNxt ? 18 : 14
		font.family: qfont.regular.name
	}
}
