# XAIGPUARC
This is a AI Installation Tool specialised for Linux 
(Arch GARUDA Family) and ARC Intel iGPUs and dGPUs / 
also older iGPUS to run over SYCL with Llama.cpp.
There are build in a lot who looks like should not be in, but belive me, some things must be other ways.

Here whe talk about to fast computers, to slow computers and so on.
No matter for you. Matter is funcution! Fast Efizient and from wishes you ever can fell free to ask.
There follow a lot usefull updates who i created from scratch like everytime.

my own way :-)
USE Big Modells!!! Q8/Q6 !!! FP16 half Calculation, double Performance, quad Quality with Q8 and Q6 Modells ONLY!!! 

NOT USEABLE WITH LOW END Modells!!!
On 16GB ARC A770 you will youse the Math Tutor and no other for two years of reasearch. ;-) 
I hope you like the small builds and use solar 10.7b Q6 IQ for the first time, llama3 12b also works in Q6 fine. 
11,5 Gib VRAM needet for that. If you use you normal RAM, try to make him fast as possible. 
Testest well with 718 Gib/s Bandwith on Claw Quad Cannel Meteor Lake Mod.

If you are a Windows User, i personal recommend to use the AIPlayground Programm from Intel itself! 
You see there is no need to make a Windows Version of XAIGPUARC. 
(Update 1 DEZ.25 Now i think this is way faster in the special cases woh it works fine!!!)

A Pro Version with also own made Code from Scratch is comming soon only for Customers.
Let us make AI usefull and less expensive for your Company.

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

Manuelle Abhängigkeiten: In einigen Fällen, insbesondere wenn das PREXAIGPUARC.sh-Skript 
die erforderlichen oneAPI-Bibliotheken nicht findet, kann es notwendig sein,
die relevanten Pakete wie intel-oneapi-basekit oder unter 
Arch/Garuda das onednn Paket manuell über den Paketmanager zu installieren.
