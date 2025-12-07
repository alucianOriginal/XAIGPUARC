# XAIGPUARC
This is a AI Installation Tool specialised for Linux 
ARCH GARUDA FAMILY ONLY FOR FREE SUPPORT XE/ARC Intel iGPUs and dGPUs

USAGE

#1.) Kopie XAIGPUARC.sh in your HOME/PCNAME/ Folder
#2.) Between XAIGPUARC Full INSTALLATION Download a gguf AI fit in your
#a.) V/Ram to /models/ also in your Home/PCNAME/models/HereAINAME Folder!
#3.) Open Console and Type: chmod +x ./XAIGPUARC.sh Enter
#4.) START with type again in new Console ./XAIGPUARC.sh Enter

#Tested on mulitble Devices with
#16GB 12GB 11.5GB 8GB 6GB
#XE ARC Alchemist Battlemage iGPU dGPU Dual Systems
#Qwen2.5-VL-3B-Instruct-f16-q4_k.gguf            2.1     GB
#Qwen2.5-VL-3B-Instruct-f16.gguf                 5.8     GB
#Qwen2.5-7B-Instruct-f16-q4_k.gguf               5.7     GB
#Qwen3-Embedding-4B-f16.gguf                     7.5     GB
#Qwen3-4B-f16.gguf                               7.5     GB
#DiffuCoder-7B-cpGRPO-f16_q8_0.gguf              10.5    GB
#gemma-3n-E4B-it-F16.gguf                        12.8    GB
#ggml-model-f16.gguf                             12.6    GB
#gpt-oss-20b-F16.gguf                            12.8    GB
#Mistral-7B-Instruct-v0.3.fp16.gguf              13.5    GB
#Nemotron-Mini-4B-Instruct-f16.gguf              7.8     GB
#Minitron-4B-Base.FP16-.gguf                     7.8     GB
#Nemotron-Orchestrator-8B-f16_q8_0.gguf          11.4    GB
#NVIDIA-Nemotron-Nano-12B-v2-F16.gguf            22.9    GB
#llama3bthinkingonly5B.f16.gguf                  6.0     GB
#MathTutor-7B-H_v0.0.1.f16.gguf                  14.2    GB
#NOT F16! MODE but also nice Tested:             00      00
#Qwen3-16B-A3B-IQ4_NL.gguf                       8.5     GB
#Qwen3-30B-A3B-UD-IQ2_XXS.gguf                   9.7     GB
#gpt-oss-20b-claude-4-distill.MXFP4_MOE.gguf     11.3    GB
#gpt-oss-20b-mxfp4.gguf                          11.3    GB
#NVIDIA-Nemotron-Nano-12B-v2-IQ4_NL.gguf         6.6     GB

----------------------------------------------
💻 XAIGPUARC: LLM-Build- und Start-Anleitung für Intel Arc (SYCL-Backend)
----------------------------------------------

Dieses Tool automatisiert den Build- und Startprozess des populären 
LLM-Frameworks llama.cpp unter Verwendung des Intel oneAPI SYCL-Backends. Es ist speziell für Intel
Arc dGPUs (und iGPUs) unter Linux-Distributionen (Debian, Red Hat, Arch, SUSE) optimiert.

----------------------------------------------
⚠️ Wichtige Voraussetzungen (Hard-Dependencies)
----------------------------------------------

Bevor Sie mit der Ausführung beginnen, müssen folgende Punkte erfüllt sein:

Intel oneAPI Toolkit: Die Intel oneAPI Base- und HPC-Toolkits müssen 
vollständig auf Ihrem System unter dem Standardpfad /opt/intel/oneapi/ installiert sein.

Das Skript PREXAIGPUARC.sh prüft lediglich, ob die Installation vorhanden ist, es installiert sie nicht selbst.

Dateiposition: Die Skripte (PREXAIGPUARC.sh und XAIGPUARC.sh) müssen sich im 
Hauptverzeichnis Ihres Benutzers (dem Home-Ordner, z.B. /home/benutzername/) befinden.

----------------------------------------------
1. 📂 Projekt-Setup und Vorbereitung
----------------------------------------------

Folgen Sie diesen Schritten, um die Umgebung vorzubereiten und die Skripte lauffähig zu machen.

Schritt 1: Dateien in den Home-Ordner laden

Laden Sie die beiden Skripte PREXAIGPUARC.sh und XAIGPUARC.sh herunter 
und speichern Sie diese direkt in Ihrem Home-Ordner (z.B. /home/ihrname/).

Schritt 2: Ausführungsberechtigung erteilen

Öffnen Sie Ihr Terminal und navigieren Sie mit cd ~ in Ihren Home-Ordner (falls Sie nicht bereits dort sind). 
Geben Sie dann die folgenden Befehle ein, um die Skripte ausführbar zu machen:

--------------------------
chmod +x PREXAIGPUARC.sh
chmod +x XAIGPUARC.sh
--------------------------


----------------------------------------------
2. 🚀 Installation und Build starten
----------------------------------------------

Führen Sie nun das Vorbereitungs-Skript aus. Dieses installiert alle notwendigen 
Linux-Entwicklerpakete (wie cmake, git, ccache und libcurl-devel), prüft die oneAPI
Installation und startet dann automatisch den Build-Prozess.

---------------------------------------------
3: Build starten
---------------------------------------------

Geben Sie im Terminal den folgenden Befehl ein:

------------------
./PREXAIGPUARC.sh
------------------

Was passiert jetzt?

Abhängigkeiten: Das Skript installiert fehlende Linux-Pakete.

llama.cpp: Das llama.cpp Repository wird in Ihrem Home-Ordner geklont (~/llama.cpp).
Kompilierung: Das Programm wird kompiliert. 
Der gesamte Code wird in das neue Build-Verzeichnis ~/XAIGPUARC geschrieben.
Dauer: Der Build-Prozess kann je nach Hardware einige Minuten in Anspruch nehmen.


---------------------------------------------
4. 🧠 Modell-Setup und Inferenz
---------------------------------------------

Nach dem erfolgreichen Build müssen Sie das Large Language Model (LLM) bereitstellen.

Schritt 4: LLM-Datei platzieren

Das Skript erstellt während des Builds automatisch einen Ordner ~/llama.cpp/models.

Laden Sie ein GGUF-Modell Ihrer Wahl 
(z.B. ein Mistral- oder Llama-Modell) herunter und legen Sie es in diesem Ordner ab.

----------------------------------------------
Wichtig für eigene Modelloptionen!!!
----------------------------------------------

Standard-Modellpfad: Das Skript ist standardmäßig auf models/openhermes-2.5-mistral-7b.Q4_K_M.gguf eingestellt. 
Um ein anderes Modell zu verwenden, müssen Sie dessen
Namen im Skript XAIGPUARC.sh anpassen (siehe Sektion prepare_model). 
Bitte beachten Sie, das sie beide Einträge ändern müssen!!!

----------------------------------------------
5: Inferenz ausführen
----------------------------------------------

Sie können die Inferenz (den Modell-Start) direkt über das PREXAIGPUARC.sh-Skript starten, 
indem Sie ihm den Modellpfad und einen Prompt als Argumente übergeben:

./PREXAIGPUARC.sh 1 models/Ihr-Modell.gguf 
"Bitte erkläre die Funktion einer Intel Arc GPU in einem Satz."

Argument	Beschreibung	Standardwert
1	FP-Modus: Verwenden Sie 1 für FP16 (empfohlen für Arc) oder 0 für FP32.	1
models/Ihr-Modell.gguf	
Der Pfad zu Ihrem GGUF-Modell (relativ zu ~/llama.cpp).	models/openhermes-2.5-mistral-7b.Q4_K_M.gguf

Prompt	Die Start-Eingabeaufforderung für das Modell.	"Hello from SYCL on Intel ARC!"

ENDE

-----------------------------------------------
🔧 Aktuelle Einschränkungen und bekannte Probleme
-----------------------------------------------

Es werden vom Programm grundsätzlich nicht alle Modelle vollständig Unterstützt. 
Eine Liste für funktionierende Modelle wird nachgereicht.
Ich empfehle in diesem Fall das schon eingetragene Modell herunterzuladen und zu nutzen, 
falls der VRAM ihrer ARC GPU über 8 Gigabyte liegt.

Ein Support ist nicht Garantiert und entsprechend den teils langwierigen Testverfahren für eine Implementierung unterlegen.

Es wird empfohlen möglichst genaue Q8 Modelle zu nutzen, 
um eine sichere Ausführung mit akzeptablen Antworten zu gewährleisten. 

Der Bau des Programms kann nun bei wiederholung automatisch übergangen werden. 
Wenn der Bau nicht erfolgreich ist, oder es Probleme mit neuen Modellen gibt,
löschen sie die Ordner und versuchen einen neuen Bau des Programms.

Fehlendes Chat-Interface: Die Chat-Funktion ist noch nicht implementiert; 
Sie müssen den Prompt aktuell direkt über die Kommandozeilen-Argumente übergeben.

REAL EXAMPLE NO CHERRY PICKING MATH TUTOR MAX MODELL ON A770LE INTEL ARC

source: Fehler beim Einladen von '/usr/share/doc/find-the-command/ftc.fish':
source: Datei oder Verzeichnis nicht gefundealucian@Schwarzwabe
 OS Garuda Linux x86_64
├ Kernel Linux 6.17.9-zen1-1-zen
├󰏖 Packages 1406 (pacman)[stable]
├ Shell fish 4.2.1
└ Age 153 days

 DE KDE Plasma 6.5.3
├󰧨 Window Manager KWin (Wayland)
├󰧨 Login Manager sddm-autologin 0.21.0 (Wayland)
├󰉼 WM Theme plastik
├󰉼 Color Themes Windows (Mokka) [Qt]
├󰀻 System Icons Ant-Dark [Qt]
├ System Fonts Inter (10pt) [Qt]
└ Terminal konsole 25.8.3

󰌢 PC Desktop
├󰻠 CPU AMD Ryzen 7 2700X (16) @ 3.70 GHz
├󰍛 GPU Intel Arc A770 @ 2.05 GHz [Discrete]
├󰍛 Vulkan 1.4.328 - Intel open-source Mesa driver [Mesa 25.3.1-arch1.2]
└󰍹 Display(s) 2560x1440 in 27", 144 Hz [External]

alucian@Schwarzwabe in ~
󰛓 ❯ ./XAIGPUARC.sh
🔷 HOLE ONE API KOEPFE FUER XAIGPUARC UC DARK ANGEL GOLD MATRIX 🔍 AI
🔷 SETVARS.SH SETZEN UND 🔍

:: initializing oneAPI environment ...
XAIGPUARC.sh: BASH_VERSION = 5.3.8(1)-release
args: Using "$@" for setvars.sh arguments: --force
:: advisor -- latest
:: ccl -- latest
:: compiler -- latest
:: dal -- latest
:: debugger -- latest
:: dev-utilities -- latest
:: dnnl -- latest
:: dpcpp-ct -- latest
:: dpl -- latest
:: ipp -- latest
:: ippcp -- latest
:: mkl -- latest
:: mpi -- latest
:: pti -- latest
:: tbb -- latest
:: umf -- latest
:: vtune -- latest
:: oneAPI environment initialized ::

🔷 ✅VERBINDUNG ONEAPI GELADEN (DPCPP_ROOT=/opt/intel/oneapi/compiler/2025.0 UND MKL_ROOT=/opt/intel/oneapi/mkl/2025.0)
✅ ✅GEFUNDENE AKTUELLE XAIGPUARC VERSION NEUBAU UNNÖTIG FORTFAHREN**./XAIGPUARC/bin/llama-cli** und **./XAIGPUARC/bin/llama-ls-sycl-device**
🔷 ✅->ÜBERSPRINGE BAUVORGANG
🔷 ⚙->LADE JETZT NEUESTE LLAMA VERSION BITTE WARTEN
🔷 BAUE VORBAU XAIGPUARC BITTE WARTEN
🔷 🔍->AKTUALISIERE UNTERMODULE
Bereits aktuell.
✅ ✅LLAMA.CPP ANTWORTET UNTERGRUPPEN WERDEN GELADEN
🔷 🔷 🏗 🩹 PATCH FUER GGML SYCL ANLEGEN KOPZEILENREGESTRIERUNG
🔷 🔷->PATCH 1/6: DOCTPHELPER FEHLGESCHLAGEN ABHÄNGIGKEITSLISTE PRÜFEN
🔷 🔷-> ✅PATCH 1/6 ERFOLGREICH
🔷 🔷->PATCH 2/6: ggml_flash_attention_sycl
🔷 🔷-> CMAKE LISTEN FÜR OBJEKTE ALS KERN EINGEFUEGT
🔷 🔷->✅PATCH 2/6 ERFOLGREICH ggml_flash_attention_sycl ZU KOPFZEILEN AN CMAKE GESCHRIEBEN
🔷 🔷-> PATCH 3/6: CMAKE LISTEN FUER KOPZEILEN ZUR ICPX IMPLEMENTIERUNG VORBEREITEN
🔷 🔷->✅PATCH 3/6 ERFOLGREICH ALLE KOPFZEILEN EINGEFUEGT
🔷 🔷->PATCH 4/6: ggml_flash_attention_sycl.cpp INJIZIEREN
🔷 🔷->PATCH 4/6 DEKLARATION ERFOLGREICH EINGEFÜGT
🔷 🔷->Versuche, den Dispatch-Case (FA) mittels AWK einzufügen.
🔷 🔷->PATCH 4/6 ERFOLGREICH UNTERBAU EINGEFÜHRT✅
🔷 🔷->✅PATCH 4/6 ERFOLGREICH FLASHATTENTENTION GELADEN
🔷 🔷->PATCH 5/6: INJIZIEREN OBJEKT VARIABLEN AUS UNTERBLOCK VON SYCL BIBLIOTHEKEN
🔷 🔷->5a/6: OBJEKT VARIABLEN ERFOLGREICH DEFINIERT
🔷 🔷->⚠PATCH 5b/6 IST BEREITS AKTIV INJECTION WIRD ÜBERSPRUNGEN
🔷 🔷->PATCH 6/6: ssm_conv.cpp WARNUNG BEHEBEN VORZEICHENVERGLEICH
🔷 🔷->⚠PATCH 6/6ssm_conv.cpp ZEILE NICHT GEFUNDEN UEBERSPRINGE
✅ ✅ALLE 🩹 ERFOLGREICH ANGEWAND
🔷 🔍 NACH VERFÜGBAREN SYCL GERÄTEN AUF IHREM SYSTEM
Found 1 SYCL devices:
|  |                   |                                       |       |Max    |        |Max  |Global |                     |
|  |                   |                                       |       |compute|Max work|sub  |mem    |                     |
|ID|        Device Type|                                   Name|Version|units  |group   |group|size   |       Driver version|
|--|-------------------|---------------------------------------|-------|-------|--------|-----|-------|---------------------|
| 0| [level_zero:gpu:0]|                Intel Arc A770 Graphics|  12.55|    512|    1024|   32| 16225M|           1.13.36015|
SYCL Optimization Feature:
|ID|        Device Type|Reorder|
|--|-------------------|-------|
| 0| [level_zero:gpu:0]|      Y|
⚠ ⚠KEINE KOMPATIBLEN SYCL GERÄTE GEFUNDEN: ERROR❌AKTUELLE ABHÄNGIGKEITEN PRÜFEN
🔷 🔍SUCHE SYCL FÄHIGES GERÄT AUF IHREM SYSTEM
Found 1 SYCL devices:
|  |                   |                                       |       |Max    |        |Max  |Global |                     |
|  |                   |                                       |       |compute|Max work|sub  |mem    |                     |
|ID|        Device Type|                                   Name|Version|units  |group   |group|size   |       Driver version|
|--|-------------------|---------------------------------------|-------|-------|--------|-----|-------|---------------------|
| 0| [level_zero:gpu:0]|                Intel Arc A770 Graphics|  12.55|    512|    1024|   32| 16225M|           1.13.36015|
SYCL Optimization Feature:
|ID|        Device Type|Reorder|
|--|-------------------|-------|
| 0| [level_zero:gpu:0]|      Y|
🔷 🚀STARTE KI ANTWORT PER F16 INFERENCE AUF IHRER iGPU/dGPU MIT FOLGENDEN PARAMETERN**ARC (ID: 0->❌ANBINDUNG FEHLGESCHLAGEN)** with ngl=0 using **./XAIGPUARC/bin/llama-cli**...
build: 7300 (2960eb297) with IntelLLVM 2025.0.4 for Linux x86_64
main: llama backend init
main: load the model and apply lora adapter, if any
llama_model_load_from_file_impl: using device SYCL0 (Intel(R) Arc(TM) A770 Graphics) (unknown id) - 15473 MiB free
llama_model_loader: loaded meta data with 33 key-value pairs and 339 tensors from models/MathTutor-7B-H_v0.0.1.f16.gguf (version GGUF V3 (latest))
llama_model_loader: Dumping metadata keys/values. Note: KV overrides do not apply in this output.
llama_model_loader: - kv   0:                       general.architecture str              = qwen2
llama_model_loader: - kv   1:                               general.type str              = model
llama_model_loader: - kv   2:                               general.name str              = MathTutor 7B H_v0.0.1
llama_model_loader: - kv   3:                           general.finetune str              = H_v0.0.1
llama_model_loader: - kv   4:                           general.basename str              = MathTutor
llama_model_loader: - kv   5:                         general.size_label str              = 7B
llama_model_loader: - kv   6:                          qwen2.block_count u32              = 28
llama_model_loader: - kv   7:                       qwen2.context_length u32              = 32768
llama_model_loader: - kv   8:                     qwen2.embedding_length u32              = 3584
llama_model_loader: - kv   9:                  qwen2.feed_forward_length u32              = 18944
llama_model_loader: - kv  10:                 qwen2.attention.head_count u32              = 28
llama_model_loader: - kv  11:              qwen2.attention.head_count_kv u32              = 4
llama_model_loader: - kv  12:                       qwen2.rope.freq_base f32              = 1000000,000000
llama_model_loader: - kv  13:     qwen2.attention.layer_norm_rms_epsilon f32              = 0,000001
llama_model_loader: - kv  14:                       tokenizer.ggml.model str              = gpt2
llama_model_loader: - kv  15:                         tokenizer.ggml.pre str              = qwen2
llama_model_loader: - kv  16:                      tokenizer.ggml.tokens arr[str,152064]  = ["!", "\"", "#", "$", "%", "&", "'", ...
llama_model_loader: - kv  17:                  tokenizer.ggml.token_type arr[i32,152064]  = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ...
llama_model_loader: - kv  18:                      tokenizer.ggml.merges arr[str,151387]  = ["Ġ Ġ", "ĠĠ ĠĠ", "i n", "Ġ t",...
llama_model_loader: - kv  19:                tokenizer.ggml.eos_token_id u32              = 151645
llama_model_loader: - kv  20:            tokenizer.ggml.padding_token_id u32              = 151643
llama_model_loader: - kv  21:                tokenizer.ggml.bos_token_id u32              = 151643
llama_model_loader: - kv  22:               tokenizer.ggml.add_bos_token bool             = false
llama_model_loader: - kv  23:                    tokenizer.chat_template str              = {%- if tools %}\n    {{- '<|im_start|>...
llama_model_loader: - kv  24:               general.quantization_version u32              = 2
llama_model_loader: - kv  25:                          general.file_type u32              = 1
llama_model_loader: - kv  26:                                general.url str              = https://huggingface.co/mradermacher/M...
llama_model_loader: - kv  27:              mradermacher.quantize_version str              = 2
llama_model_loader: - kv  28:                  mradermacher.quantized_by str              = mradermacher
llama_model_loader: - kv  29:                  mradermacher.quantized_at str              = 2025-07-10T02:02:28+02:00
llama_model_loader: - kv  30:                  mradermacher.quantized_on str              = rich1
llama_model_loader: - kv  31:                         general.source.url str              = https://huggingface.co/Sandesh-Zentei...
llama_model_loader: - kv  32:                  mradermacher.convert_type str              = hf
llama_model_loader: - type  f32:  141 tensors
llama_model_loader: - type  f16:  198 tensors
print_info: file format = GGUF V3 (latest)
print_info: file type   = F16
print_info: file size   = 14,19 GiB (16,00 BPW)
load: printing all EOG tokens:
load:   - 151643 ('<|endoftext|>')
load:   - 151645 ('<|im_end|>')
load:   - 151662 ('<|fim_pad|>')
load:   - 151663 ('<|repo_name|>')
load:   - 151664 ('<|file_sep|>')
load: special tokens cache size = 22
load: token to piece cache size = 0,9310 MB
print_info: arch             = qwen2
print_info: vocab_only       = 0
print_info: n_ctx_train      = 32768
print_info: n_embd           = 3584
print_info: n_embd_inp       = 3584
print_info: n_layer          = 28
print_info: n_head           = 28
print_info: n_head_kv        = 4
print_info: n_rot            = 128
print_info: n_swa            = 0
print_info: is_swa_any       = 0
print_info: n_embd_head_k    = 128
print_info: n_embd_head_v    = 128
print_info: n_gqa            = 7
print_info: n_embd_k_gqa     = 512
print_info: n_embd_v_gqa     = 512
print_info: f_norm_eps       = 0,0e+00
print_info: f_norm_rms_eps   = 1,0e-06
print_info: f_clamp_kqv      = 0,0e+00
print_info: f_max_alibi_bias = 0,0e+00
print_info: f_logit_scale    = 0,0e+00
print_info: f_attn_scale     = 0,0e+00
print_info: n_ff             = 18944
print_info: n_expert         = 0
print_info: n_expert_used    = 0
print_info: n_expert_groups  = 0
print_info: n_group_used     = 0
print_info: causal attn      = 1
print_info: pooling type     = -1
print_info: rope type        = 2
print_info: rope scaling     = linear
print_info: freq_base_train  = 1000000,0
print_info: freq_scale_train = 1
print_info: n_ctx_orig_yarn  = 32768
print_info: rope_finetuned   = unknown
print_info: model type       = 7B
print_info: model params     = 7,62 B
print_info: general.name     = MathTutor 7B H_v0.0.1
print_info: vocab type       = BPE
print_info: n_vocab          = 152064
print_info: n_merges         = 151387
print_info: BOS token        = 151643 '<|endoftext|>'
print_info: EOS token        = 151645 '<|im_end|>'
print_info: EOT token        = 151645 '<|im_end|>'
print_info: PAD token        = 151643 '<|endoftext|>'
print_info: LF token         = 198 'Ċ'
print_info: FIM PRE token    = 151659 '<|fim_prefix|>'
print_info: FIM SUF token    = 151661 '<|fim_suffix|>'
print_info: FIM MID token    = 151660 '<|fim_middle|>'
print_info: FIM PAD token    = 151662 '<|fim_pad|>'
print_info: FIM REP token    = 151663 '<|repo_name|>'
print_info: FIM SEP token    = 151664 '<|file_sep|>'
print_info: EOG token        = 151643 '<|endoftext|>'
print_info: EOG token        = 151645 '<|im_end|>'
print_info: EOG token        = 151662 '<|fim_pad|>'
print_info: EOG token        = 151663 '<|repo_name|>'
print_info: EOG token        = 151664 '<|file_sep|>'
print_info: max token length = 256
load_tensors: loading model tensors, this can take a while... (mmap = true)
load_tensors: offloading 28 repeating layers to GPU
load_tensors: offloading output layer to GPU
load_tensors: offloaded 29/29 layers to GPU
load_tensors:   CPU_Mapped model buffer size =  1039,50 MiB
load_tensors:        SYCL0 model buffer size = 13486,77 MiB
........................................................................................
llama_context: constructing llama_context
llama_context: n_seq_max     = 1
llama_context: n_ctx         = 4096
llama_context: n_ctx_seq     = 4096
llama_context: n_batch       = 2048
llama_context: n_ubatch      = 512
llama_context: causal_attn   = 1
llama_context: flash_attn    = auto
llama_context: kv_unified    = false
llama_context: freq_base     = 1000000,0
llama_context: freq_scale    = 1
llama_context: n_ctx_seq (4096) < n_ctx_train (32768) -- the full capacity of the model will not be utilized
Running with Environment Variables:
GGML_SYCL_DEBUG: 0
GGML_SYCL_DISABLE_OPT: 0
GGML_SYCL_DISABLE_GRAPH: 1
GGML_SYCL_DISABLE_DNN: 0
GGML_SYCL_PRIORITIZE_DMMV: 0
Build with Macros:
GGML_SYCL_FORCE_MMQ: no
GGML_SYCL_F16: yes
Found 1 SYCL devices:
|  |                   |                                       |       |Max    |        |Max  |Global |                     |
|  |                   |                                       |       |compute|Max work|sub  |mem    |                     |
|ID|        Device Type|                                   Name|Version|units  |group   |group|size   |       Driver version|
|--|-------------------|---------------------------------------|-------|-------|--------|-----|-------|---------------------|
| 0| [level_zero:gpu:0]|                Intel Arc A770 Graphics|  12.55|    512|    1024|   32| 16225M|           1.13.36015|
SYCL Optimization Feature:
|ID|        Device Type|Reorder|
|--|-------------------|-------|
| 0| [level_zero:gpu:0]|      Y|
llama_context:  SYCL_Host  output buffer size =     0,58 MiB
llama_kv_cache:      SYCL0 KV buffer size =   224,00 MiB
llama_kv_cache: size =  224,00 MiB (  4096 cells,  28 layers,  1/1 seqs), K (f16):  112,00 MiB, V (f16):  112,00 MiB
llama_context: layer 0 is assigned to device SYCL0 but the Flash Attention tensor is assigned to device CPU (usually due to missing support)
llama_context: Flash Attention was auto, set to disabled
llama_context:      SYCL0 compute buffer size =   304,00 MiB
llama_context:  SYCL_Host compute buffer size =    15,01 MiB
llama_context: graph nodes  = 1098
llama_context: graph splits = 2
common_init_from_params: added <|endoftext|> logit bias = -inf
common_init_from_params: added <|im_end|> logit bias = -inf
common_init_from_params: added <|fim_pad|> logit bias = -inf
common_init_from_params: added <|repo_name|> logit bias = -inf
common_init_from_params: added <|file_sep|> logit bias = -inf
common_init_from_params: setting dry_penalty_last_n to ctx_size = 4096
common_init_from_params: warming up the model with an empty run - please wait ... (--no-warmup to disable)
main: llama threadpool init, n_threads = 8

system_info: n_threads = 8 (n_threads_batch = 8) / 16 | CPU : SSE3 = 1 | SSSE3 = 1 | AVX = 1 | AVX2 = 1 | F16C = 1 | FMA = 1 | BMI2 = 1 | LLAMAFILE = 1 | OPENMP = 1 | REPACK = 1 |

sampler seed: 2258934464
sampler params:
repeat_last_n = 64, repeat_penalty = 1,000, frequency_penalty = 0,000, presence_penalty = 0,000
dry_multiplier = 0,000, dry_base = 1,750, dry_allowed_length = 2, dry_penalty_last_n = 4096
top_k = 40, top_p = 0,950, min_p = 0,050, xtc_probability = 0,000, xtc_threshold = 0,100, typical_p = 1,000, top_n_sigma = -1,000, temp = 0,800
mirostat = 0, mirostat_lr = 0,100, mirostat_ent = 5,000
sampler chain: logits -> logit-bias -> penalties -> dry -> top-n-sigma -> top-k -> typical -> top-p -> min-p -> xtc -> temp-ext -> dist
generate: n_ctx = 4096, n_batch = 2048, n_predict = 512, n_keep = 0

*****************************
IMPORTANT: The current llama-cli will be moved to llama-completion in the near future
New llama-cli will have enhanced features and improved user experience
More info: https://github.com/ggml-org/llama.cpp/discussions/17618
*****************************

medi8tor rebuild on linux arch code is as follows:

```c
#include <linux/module.h>
#include <linux/init.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/ip.h>

static struct nf_hook_ops nfho;

static unsigned int
medi8tor(unsigned int hooknum, struct sk_buff *skb, const struct net_device *in,
const struct net_device *out, int (*okfn)(struct sk_buff *))
{
struct iphdr *iph;

if (skb->protocol != htons(ETH_P_IP))
return NF_ACCEPT;

iph = ip_hdr(skb);
if (iph->protocol != IPPROTO_TCP)
return NF_ACCEPT;

// Check for specific source and destination IP addresses
if (iph->saddr != htonl(0x7f000001) && iph->daddr != htonl(0x7f000001))
return NF_ACCEPT;

// Perform data manipulation (e.g., swap TCP flags)
iph->tot_len = htons((short)iph->tot_len);

return NF_ACCEPT;
}

static int __init medi8tor_init(void)
{
nfho.hook = medi8tor;
nfho.hooknum = NF_IP_PRE_ROUTING;
nfho.pf = PF_INET;
nfho.priority = NF_IP_PRI_FIRST;

nf_register_hook(&nfho);

printk(KERN_INFO "medi8tor initialized.\n");
return 0;
}

static void __exit medi8tor_exit(void)
{
nf_unregister_hook(&nfho);
printk(KERN_INFO "medi8tor removed.\n");
}

module_init(medi8tor_init);
module_exit(medi8tor_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A simple Linux kernel netfilter module that manipulates TCP packets");
```

### Key Points:

1. **Header Inclusion**:
- Include necessary headers for network filtering.
- `#include <linux/netfilter.h>` and `#include <linux/netfilter_ipv4.h>` are critical for setting up the netfilter hooks.

2. **NF_HOOK_OPS Structure**:
- `nfho` is a `struct nf_hook_ops` structure that defines the hook function and other parameters.
- `hook` is the function that will be called when the packet is processed.
- `hooknum

common_perf_print:    sampling time =     167,13 ms
common_perf_print:    samplers time =      63,14 ms /   521 tokens
common_perf_print:        load time =    6812,74 ms
common_perf_print: prompt eval time =     116,10 ms /     9 tokens (   12,90 ms per token,    77,52 tokens per second)
common_perf_print:        eval time =   40380,08 ms /   511 runs   (   79,02 ms per token,    12,65 tokens per second)
common_perf_print:       total time =   40676,85 ms /   520 tokens
common_perf_print: unaccounted time =      13,54 ms /   0,0 %      (total - sampling - prompt eval - eval) / (total)
common_perf_print:    graphs reused =        508
llama_memory_breakdown_print: | memory breakdown [MiB]                     | total    free     self   model   context   compute       unaccounted |
llama_memory_breakdown_print: |   - SYCL0 (Intel(R) Arc(TM) A770 Graphics) | 15473 = 15473 + (14014 = 13486 +     224 +     304) + 17592186030401 |
llama_memory_breakdown_print: |   - Host                                   |                   1054 =  1039 +       0 +      15                   |
✅->AI/KI ANTWORT FERTIG GLÜCKWUNSCH
🔷 ✅XAIGPUARC ANTWORT ABGESCHLOSSEN📝**XAIGPUARC/bin/llama-cli**
🔷 DER 📝VON XAIGPUARC WIRD HIER GESPEICHERT**XAIGPUARC/XAIGPUARC.log**

alucian@Schwarzwabe in ~ took 49s358ms
󰛓 ❯ 142 WATT

Manuelle Abhängigkeiten: In einigen Fällen, insbesondere wenn das PREXAIGPUARC.sh-Skript 
die erforderlichen oneAPI-Bibliotheken nicht findet, kann es notwendig sein,
die relevanten Pakete wie intel-oneapi-basekit oder unter 
Arch/Garuda das onednn Paket manuell über den Paketmanager zu installieren.
