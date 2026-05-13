# WinCaffe Lite Pro Gaming Edition

Versione: `1.0a`

WinCaffe Lite Pro Gaming Edition e' uno script PowerShell per ottimizzazione Windows orientata al gaming high-FPS, con focus particolare su `Call of Duty: Black Ops 7`.

## Obiettivo

- ridurre overhead e rumore di fondo del sistema
- allineare Game Mode, DVR, Flip Model e power plan
- offrire moduli separati per tuning, debloat e File I/O
- mantenere un approccio prudente verso anti-cheat, compatibilita' e rollback

## Moduli principali

- `BASE`: core gaming Windows
- `BO7`: rifiniture specifiche per Black Ops 7 lato Windows
- `DEBLOAT`: rimozione app consumer e servizi secondari non essenziali
- `FILE I/O`: ottimizzazioni safe per NTFS, TRIM, trasferimenti e caricamenti
- `ALL`: applica tutti i moduli in sequenza

## Utility

- installazione/rimozione watcher opzionale
- HAGS ON/OFF manuale
- quick report
- rollback da backup
- restore point prima di ogni azione

## Intro retro

All'avvio lo script mostra un'intro stile vecchio gioco DOS con logo animato, righe di boot e loading bar.

Audio supportato sul Desktop:

- `theme.mp3`
- `WinCaffe_Intro.wav`

Se nessun file audio e' presente, viene usata una breve sequenza di beep retro integrata.

## Avvio

```powershell
& "C:\Users\Admin\Desktop\WinCaffe Lite Pro Gaming Edition\WinCaffe Lite Pro Gaming Edition.ps1"
```

## Note

- il watcher resta opzionale e meno consigliato con anti-cheat molto sensibili
- il preset non modifica file di gioco e non include bypass anti-cheat
- riavvio consigliato dopo l'applicazione dei moduli

## Licenza

Questo progetto e' distribuito sotto `GNU General Public License v3.0 (GPL-3.0)`.

Vedi [LICENSE](./LICENSE) oppure:

[https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html)
