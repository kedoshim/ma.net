# Playnite Preset Script Snippets

Here are the ready-to-copy PowerShell script snippets for all built-in presets in MaNet. Paste these into Playnite's **"Before launching game, execute script"** text box.

By default, these scripts target port `8765`. If you configure MaNet to use a different port, update the `8765` in the Uri to match.

---

### Simple + Shoulder
* **Preset ID:** `builtin-simple-shoulder`
* **Preset Name:** `Simple + Shoulder`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "builtin-simple-shoulder"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Simple + Shoulder"}'
```

---

### Simple + Trigger
* **Preset ID:** `builtin-simple-trigger`
* **Preset Name:** `Simple + Trigger`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "builtin-simple-trigger"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Simple + Trigger"}'
```

---

### Complete
* **Preset ID:** `builtin-full`
* **Preset Name:** `Complete`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "builtin-full"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Complete"}'
```

---

### Overcooked
* **Preset ID:** `game-overcooked`
* **Preset Name:** `Overcooked`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-overcooked"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Overcooked"}'
```

---

### Pico Park
* **Preset ID:** `game-pico-park`
* **Preset Name:** `Pico Park`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-pico-park"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Pico Park"}'
```

---

### Boomerang Fu
* **Preset ID:** `game-boomerang-fu`
* **Preset Name:** `Boomerang Fu`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-boomerang-fu"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Boomerang Fu"}'
```

---

### Lego Party
* **Preset ID:** `game-lego-party`
* **Preset Name:** `Lego Party`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-lego-party"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Lego Party"}'
```

---

### Mario Kart 8
* **Preset ID:** `game-mario-kart-8`
* **Preset Name:** `Mario Kart 8`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-mario-kart-8"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Mario Kart 8"}'
```

---

### Towerfall
* **Preset ID:** `game-towerfall`
* **Preset Name:** `Towerfall`

#### PowerShell Script (Recommended: By ID)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetId": "game-towerfall"}'
```

#### PowerShell Script (By Name)
```powershell
Invoke-RestMethod `
  -Uri "http://localhost:8765/api/presets/apply" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"presetName": "Towerfall"}'
```
