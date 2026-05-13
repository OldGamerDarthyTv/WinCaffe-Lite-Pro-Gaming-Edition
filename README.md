# 🎮 WinCaffe Lite Pro Gaming Edition

> **Versione attuale:** `1.0a`  
> **Target:** Windows gaming high-FPS con focus speciale su `Call of Duty: Black Ops 7`

WinCaffe Lite Pro Gaming Edition e' uno script PowerShell pensato per ottimizzare Windows in modo pratico e leggibile, mantenendo un approccio tecnico ma prudente verso compatibilita', anti-cheat e rollback.

## ⚡ Obiettivo

- ridurre overhead e rumore di fondo del sistema
- allineare `Game Mode`, `DVR`, `Flip Model` e `power plan`
- offrire moduli separati per tuning, debloat e `File I/O`
- preservare un approccio compatibile con launcher, login Microsoft e anti-cheat comuni

## 🧩 Moduli Principali

- `BASE`
  Core gaming Windows: Game Mode, DVR OFF, Flip Model, power plan dedicato e tuning prudente.
- `BO7`
  Rifiniture specifiche per Black Ops 7 lato Windows, senza modificare file di gioco o anti-cheat.
- `DEBLOAT`
  Rimozione app consumer e servizi secondari non essenziali, con profilo gaming-safe.
- `FILE I/O`
  Ottimizzazioni safe per `NTFS`, `TRIM`, trasferimenti, caricamenti e installazioni.
- `ALL`
  Applica tutto il profilo modulare in sequenza.

## 🛠️ Utility Incluse

- installazione / rimozione watcher opzionale
- `HAGS ON/OFF` manuale
- quick report tecnico
- rollback da backup
- restore point prima di ogni azione

## 🧠 Filosofia Del Preset

Questo progetto evita volutamente:

- tweak `TCP/IP` aggressivi
- bypass anti-cheat
- modifiche ai file di gioco
- tweak `TDR` da sviluppo driver
- overclock o chiavi poco difendibili

L'idea e' semplice: migliorare la coerenza del sistema per il gaming senza trasformare Windows in un laboratorio instabile.

## 📁 Intro Retro

All'avvio lo script mostra un'intro stile vecchio gioco DOS con:

- logo animato
- righe di boot
- loading bar
- audio opzionale personalizzato

### 🔊 Audio supportato sul Desktop

- `C:\Users\Admin\Desktop\theme.mp3`
- `C:\Users\Admin\Desktop\WinCaffe_Intro.wav`

Se nessun file audio e' presente, lo script usa una breve sequenza di beep retro integrata.

## 🚀 Avvio

```powershell
& "C:\Users\Admin\Desktop\WinCaffe Lite Pro Gaming Edition\WinCaffe Lite Pro Gaming Edition.ps1"
```

## 📌 Note Operative

- il watcher resta opzionale e meno consigliato con anti-cheat molto sensibili
- il preset non modifica file di gioco e non include bypass anti-cheat
- dopo l'applicazione dei moduli e' consigliato un riavvio
- per test seri su BO7 conviene usare stessa scena, stesso driver e stesso preset grafico

## 📊 Cosa Applica Davvero

- `Game Mode ON`
- `Xbox DVR / catture OFF`
- `DirectX Flip Model ON`
- profilo energia dedicato `WinCaffe Lite Pro Gaming Plan`
- scheduler Win32 reattivo ma prudente
- `WSearch` lasciato su `Manual`
- modulo BO7 con audio ducking disattivato e FSE coerente

## 🧾 Licenza

Questo progetto e' distribuito sotto **GNU General Public License v3.0 (GPL-3.0)**.

- file locale: [LICENSE](./LICENSE)
- testo ufficiale: [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)

## 🤝 Crediti Tecnici

Riferimenti pratici e storici usati durante l'evoluzione del preset:

- `OGD_WinCaffe_8.0.13.ps1`
- `OGD_WinCaffe_8.0.9FinalTest2.ps1`
- `OGD_Timer_0.5ms.ps1`

Documentazione utile:

- [Microsoft MMCSS](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service)
- [Microsoft TDR Registry Keys](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/tdr-registry-keys)
- [DirectX Team on HAGS](https://devblogs.microsoft.com/directx/hardware-accelerated-gpu-scheduling/)
