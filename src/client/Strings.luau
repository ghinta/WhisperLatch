--!strict
-- German UI texts (room content comes from the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

return table.freeze({
	roleName = table.freeze({ Seer = "Seher", Tinkerer = "Tüftler" }),
	roleTagline = table.freeze({ Seer = "Sieht die Hinweise", Tinkerer = "Bedient die Rätsel" }),
	roleIcon = table.freeze({ Seer = "◉", Tinkerer = "⚙" }),
	panelTitle = table.freeze({ Seer = "Hinweiswand", Tinkerer = "Steuerpult" }),

	lobby = table.freeze({
		subtitle = "2 Spieler, 2 Räume, 1 gemeinsame Lösung",
		seerText = "Sieht Hinweise und die geheime Reihenfolge – kann aber nichts bedienen.",
		tinkererText = "Bedient Drehscheiben, Schalter und Tasten – kennt aber die Lösung nicht.",
		steps = {
			"1. Hinweis sehen",
			"2. Beschreiben (Ping-Rad oder Chat)",
			"3. Rätsel bedienen",
			"4. Tür öffnen – gemeinsam",
		},
		swapNote = "Nach jedem Raum tauscht ihr die Rollen. 5 Räume, ca. 10–15 Minuten.",
		queue = "Partner suchen",
		queued = "Suche Partner …",
		cancel = "Abbrechen",
		friendNote = "Mit einem Freund spielen: Beide auf demselben Server „Partner suchen“ drücken.",
	}),

	hud = table.freeze({
		yourRole = "Deine Rolle:",
		room = "Raum",
		hints = "Tipps",
		requestHint = "Tipp anfordern",
		noHints = "Noch keine Tipps.",
		reset = "Raum neu mischen",
		leave = "Verlassen",
		leaveConfirm = "Wirklich verlassen?",
		pings = "Ping senden",
		feedEmpty = "Schickt euch Symbole und Zahlen über das Ping-Rad.",
		you = "Du",
		partner = "Partner",
		attempts = "Versuche",
		paused = "Dein Partner ist weg. Der Raum ist eingefroren.",
		pausedWait = "Warte auf seine Rückkehr …",
		requeue = "Neuen Partner suchen",
		toLobby = "Zur Lobby",
		legendTitle = "Symboltafel",
		close = "Schließen",
	}),

	pingCategory = table.freeze({
		status = "Status",
		glyph = "Symbole",
		number = "Zahlen",
		arrow = "Regeln",
	}),

	controls = table.freeze({
		reference = "Vorlage (nur du siehst sie)",
		yourGrid = "Dein Feld",
		stage = "Stufe",
		input = "Eingabe",
		core = "Kern",
		coreHidden = "verborgen",
		clear = "Leeren",
		on = "AN",
		off = "AUS",
		oClock = "Uhr",
		mirror = "Spiegel",
	}),

	notice = table.freeze({
		wrong = "Falsch – versucht es nochmal.",
		stage = "Stufe geschafft! Der Reaktor zeigt einen Kern.",
		solved = "Gelöst! Die Tür öffnet sich …",
		advanced = "Neuer Raum – ihr habt die Rollen getauscht.",
		reset = "Der Raum wurde neu gemischt.",
		hint = "Neuer Tipp freigeschaltet.",
		partnerLeft = "Dein Partner hat das Spiel verlassen.",
		partnerBack = "Dein Partner ist zurück!",
		finished = "Alle Räume gelöst – gemeinsam!",
		timeout = "Sitzung beendet: Partner kam nicht zurück.",
		abandoned = "Sitzung beendet.",
	}),

	rejected = table.freeze({
		cooldown = "Kurz warten …",
		wrongRole = "Das kann nur der Tüftler.",
		noHintsLeft = "Keine weiteren Tipps in diesem Raum.",
		inputFull = "Eingabe voll – Schleuse umlegen oder leeren.",
	}),

	summary = function(summary: Types.RunSummary): string
		local minutes = math.floor(summary.seconds / 60)
		local seconds = math.floor(summary.seconds % 60)
		return string.format(
			"Letzter Lauf: %d/%d Räume · %d:%02d min · %d Tipps",
			summary.roomsCleared,
			summary.roomCount,
			minutes,
			seconds,
			summary.hintsUsed
		)
	end,
})
