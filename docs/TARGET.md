# Selected VEGAS target

Confirmed on 2026-10-09. The user explicitly wants the newest locally installed
VEGAS. This host supersedes the earlier VEGAS 23 target assumption.

| Field | Verified value |
| --- | --- |
| Registered product | Boris FX Vegas Pro 2026.0.3 |
| Product version | `2026.0.3` |
| Executable file version | `2026.0.3.189` |
| Architecture | x64; PE machine `0x8664` |
| Installation folder | `C:/Program Files/BorisFX/Vegas Pro 2026/` |
| Executable | `C:/Program Files/BorisFX/Vegas Pro 2026/vegas2026.exe` |
| Executable size | 47,112,648 bytes |
| Executable SHA-256 | `2B93C6613E1BDD4A435B65F63E3FC0B0EAD9EDB06B45F2458C43B63F784A73AF` |

Evidence: uninstall registration and App Paths both point to this installation;
the actual executable version resource, SHA-256, and PE header were read without
loading the program. See F-009 and
target discovery experiment.

At initial discovery no application launch or runtime validation had run.
F-031/F-036 now record user-operated Voukoder Pro captures on these same host
bytes, including a successful render return and full template/stream evidence.
Those Voukoder captures did not validate encoded output. F-041/F-045 later
validated the custom diagnostic exporter on this host: BI_RGB 1080p, fixture
P010, repeat renders and user cancel. F-048 implements FFmpeg transport and
validates it in fiohost. F-050 confirms a first short FFmpeg-backed render on
this exact host with decoded fixture checks; broader runtime qualification is
pending. The host hash remains unchanged. See runtime proof. This is
the selected installed host, not
a statement about the newest publicly available release. Preserve this identity
in experiments; when the installed
host updates, fingerprint the new bytes and record the change before reusing
addresses, disassembly, or compatibility conclusions.

## Comparison inputs already located

| Host | Executable metadata | Local connector filenames |
| --- | --- | --- |
| `L:/Program Files/VEGAS/VEGAS Pro 23.0/vegas230.exe` | Version 23.0 (Build 278) | `FileIO Plug-Ins/voukoderplug/voukoderplug.dll`; `FileIO Plug-Ins/voukoderproplug/voukoderproplug-vegas23.dll` |
| `L:/Program Files/VEGAS/VEGAS Pro 22.0/vegas220.exe` | Version 22.0 (Build 248) | `FileIO Plug-Ins/voukoderplug/voukoderplug.dll` |
| `L:/Program Files/VEGAS/VEGAS Pro 21.0/vegas210.exe` | Version 21.0 (Build 108) | `FileIO Plug-Ins/voukoderplug/voukoderplug.dll` |

Classic discovery files `Voukoder-x64.fio2007-config` were found in each listed
host folder. VEGAS 23 also contains `VoukoderProVEGAS23-x64.fio2007-config`.
F-013 now records versions, SHA-256 and x64 PE machines for the VEGAS 23 host,
both connectors, cores and configs; see INPUT_INVENTORY.md.
The 21/22 entries remain filename/resource observations (F-010). F-030 records
the VEGAS 23 Pro capture; F-029 corrected the earlier Classic assumption.
F-017 records historical success without exact historical hashes.
Older hosts are comparison inputs;
the bridge must be validated on the selected 2026 host. The target executable
hash was rechecked unchanged during F-013.


This is an imported research identity record; it is not runtime validation of Vegas Encoder.
