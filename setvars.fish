# ~/.config/fish/functions/setvars.fish

function setvars --description 'Aktiviert die Intel oneAPI Umgebungsvariablen in Fish'
    # Pfad zum Intel setvars.sh Skript (muss mit Ihrem Installationspfad übereinstimmen)
    set BASH_SETVARS_SCRIPT /opt/intel/oneapi/setvars.sh

    if not test -f "$BASH_SETVARS_SCRIPT"
        echo "FEHLER: Intel setvars.sh wurde nicht gefunden unter $BASH_SETVARS_SCRIPT"
        return 1
    end

    echo "Aktiviere Intel oneAPI Umgebung (MKL, SYCL/C++ Headers)..."

    # Führt setvars.sh in einer temporären BASH-Instanz aus und exportiert die neuen Variablen.

    # 1. Speichere aktuelle Umgebungsvariablen von Fish
    set -l current_vars (env | cut -d= -f1)

    # 2. Führe setvars.sh in Bash aus und liste die neuen/geänderten Variablen auf
    set -l new_vars (bash -c "source $BASH_SETVARS_SCRIPT > /dev/null 2>&1; env")

    # 3. Verarbeite die Variablen: Iteriere durch alle exportierten Variablen aus Bash
    for line in $new_vars
        set -l key (echo $line | cut -d= -f1)
        set -l value (echo $line | cut -d= -f2-)

        # Nur Variablen importieren, die im setvars.sh gesetzt wurden
        if not contains $key $current_vars
            set -gx $key $value
        else if not test (env | grep "^$key=" | cut -d= -f2-) = $value
            set -gx $key $value
        end
    end
    set -l ONEAPI_INCLUDE_PATH "/opt/intel/oneapi/mkl/2025.0/include"

    # Der CPATH muss als PATH-Variable behandelt werden.
    # Überprüfen Sie, ob der Pfad bereits existiert, bevor Sie ihn hinzufügen.
    if not contains $ONEAPI_INCLUDE_PATH $CPATH
        set -gx CPATH $CPATH $ONEAPI_INCLUDE_PATH
    end

    # Oft wird auch der Compiler-Include-Pfad benötigt (z.B. für oneapi/mkl.hpp)
    set -l COMPILER_INCLUDE_PATH "/opt/intel/oneapi/compiler/2025.0/include"
    if not contains $COMPILER_INCLUDE_PATH $CPATH
        set -gx CPATH $CPATH $COMPILER_INCLUDE_PATH
    end

    # --- ENDE CPATH Ergänzung ---

    echo "✅ Intel oneAPI Umgebung aktiviert."
end
