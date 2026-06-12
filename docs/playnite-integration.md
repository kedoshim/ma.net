# Playnite Integration Guide

This guide explains how to use MaNet's local Preset Automation API to automatically switch active controller layouts when starting games in external game launchers, specifically Playnite.

## Overview

MaNet exposes a local HTTP API. Game launchers can trigger HTTP POST requests right before launching a game to ensure the correct controller preset is selected automatically.

By default, the server runs on port `8765`.

---

## API Endpoints

### 1. Apply Preset
Switch the currently active controller preset.

* **Endpoint:** `POST /api/presets/apply`
* **Content-Type:** `application/json`
* **Body Parameters (provide either `presetId` or `presetName`):**
  * `presetId` (string, optional): The exact identifier of the preset (e.g. `game-overcooked`, `game-mario-kart-8`). Recommended as it is immune to name conflicts.
  * `presetName` (string, optional): The display name of the preset (e.g. `Overcooked`, `Mario Kart 8`). Case-insensitive and whitespace-tolerant.

#### Example Request (by ID)
```json
{
  "presetId": "game-overcooked"
}
```

#### Example Request (by Name)
```json
{
  "presetName": "Mario Kart 8"
}
```

#### Response (Success)
* **Status:** `200 OK`
```json
{
  "success": true
}
```

#### Response (Errors)
* **Invalid JSON / Malformed Request:** `400 Bad Request`
```json
{
  "success": false,
  "code": "invalid_body",
  "message": "Request body must be a JSON object"
}
```
* **Missing Identifiers:** `400 Bad Request`
```json
{
  "success": false,
  "code": "invalid_request",
  "message": "Either presetId or presetName must be provided"
}
```
* **Duplicate Names (when applying by `presetName` if multiple presets share the same name):** `400 Bad Request`
```json
{
  "success": false,
  "code": "duplicate_preset_names",
  "message": "Multiple presets found with the name 'My Preset'. Please use presetId instead.",
  "matches": ["user-preset-id-1", "user-preset-id-2"]
}
```
* **Preset Not Found:** `404 Not Found`
```json
{
  "success": false,
  "code": "preset_not_found",
  "message": "Preset ID 'game-overcooked-missing' not found"
}
```

---

### 2. List Available Presets
List all built-in, game-specific, and custom user-made presets.

* **Endpoint:** `GET /api/presets`
* **Response:**
```json
[
  {
    "id": "builtin-simple-shoulder",
    "name": "Simple + Shoulder"
  },
  {
    "id": "game-overcooked",
    "name": "Overcooked"
  }
]
```

---

### 3. Get Active Preset
Check which preset is currently active.

* **Endpoint:** `GET /api/presets/current`
* **Response:**
```json
{
  "id": "game-overcooked",
  "name": "Overcooked",
  "category": "game",
  "isBuiltIn": true,
  "layout": {
    "movementMode": "floatingJoystick",
    "visibleButtons": {
      "RSB": false,
      "LSB": false,
      "LT": false,
      "RT": false,
      "LB": false,
      "RB": false,
      "Y": true,
      "B": true,
      "X": true,
      "A": true
    },
    "buttonOrder": ["Y", "B", "X", "A", "RSB", "LSB", "LT", "RT", "LB", "RB"]
  }
}
```

---

## Playnite Setup Guide

To automate preset switches in Playnite:

1. Open Playnite.
2. Select the game you want to automate (e.g., *Overcooked*).
3. Right-click the game, select **Edit**, and go to the **Scripts** tab.
4. Check **Before launching game, execute script:**
5. Add the following PowerShell snippet (replace preset ID / name and Port as needed):

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-overcooked"}'
```

---

## Troubleshooting

### Error: `Unable to connect to the remote server`
* Make sure the MaNet server is running.
* Check if you changed the port in the MaNet settings. If you use a custom port, change `8765` in the script Uri to your custom port.

### Error: `duplicate_preset_names`
* This occurs if you applied by name (e.g. `presetName`) and there are multiple custom or built-in presets with the exact same name. Update the Playnite script to use the unique `presetId` instead.
