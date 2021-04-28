#!/bin/bash
# Author           : Bartłomiej Wilczyński ( bartekw2213@gmail.com )
# Created On       : 08.04.2021
# Last Modified By : Bartłomiej Wilczyński ( bartekw2213@gmail.com )
# Last Modified On : 08.04.2021
# Version          : 1.0
#
# Description      : Program that lets you download audio or video from youtube and edit downloaded file
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)

# Narzędzia wymagane do uruchumienia skryptu:
# youtube-dl | sox | libsox-fmt-mp3 (wymagane by sox mogl operowac na plikach .mp3) | ffmpeg

DOWNLOAD_VIDEO_MODE="Pobierz Wideo"
DOWNLOAD_AUDIO_MODE="Pobierz Audio"
EDIT_VIDEO_MODE="Edytuj Wideo"
EDIT_AUDIO_MODE="Edytuj Audio"

AUDIO_CUT_OPERATION="Wytnij Fragment"
AUDIO_CHANGE_SPEED="Zmień Prędkość"
AUDIO_CHANGE_VOLUME="Zmień Głośność" 

VIDEO_CUT_OPERATION="Wytnij Fragment"
VIDEO_EXTRACT_AUDIO="Oddziel Audio"
VIDEO_CHANGE_VOLUME="Zmień Głośność" 

WRONG_LINK_MESSAGE="Podano niepoprawny link"
WRONG_INPUT_MESSAGE="Podano złe dane"
WRONG_FILE_FORMAT_MESSAGE="Plik ma zły format"
FILE_LENGTH_EXCEEDED="Przekroczono długość pliku"
UNSUCCESSFUL_OPERATION_MESSAGE="Operacja nie powiodła się, sprawdź wszystkie dane"
SUCCESSFUL_OPERATION_MESSAGE="Operacja powiodła się"

# ==================
# Funkcje pomocnicze
# ==================

# Pokazuje dialog bledu z przekazana wiadomoscia
showErrorDialog() {
    zenity --error --width=300 \
    --text="$1"
}

# Pokazuje dialog powodzenia z przekazana wiadomoscia
showSuccessDialog() {
    zenity --info --width=300 \
    --text="$1"
}

# Pokazuje efekt wykonanej operacji
showOperationResult() {
    if [[ $1 = 1 ]]; then
        showErrorDialog "$UNSUCCESSFUL_OPERATION_MESSAGE"
    else 
        showSuccessDialog "$SUCCESSFUL_OPERATION_MESSAGE"
    fi
}

# Kończy skrypt jesli uzytkownik wyszedl z Dialogu Zenity
exitIfUserLeftProgram() {
    if [[ $1 != 0 ]]; then
        exit
    fi
}

exitIfInputIsEmpty() {
    if [[ -z "$1" ]]; then
        exit
    fi
}

# ===============================
# Ogolne funkcje dotyczace edycji
# ===============================

# Pyta gdzie zapisać zedytowany plik
chooseWhereStoreEditedFile() {
    local DESTINATION_FOLDER=$(zenity --file-selection --title="Wybierz Katalog Dla Nowego Pliku" --directory)
    exitIfInputIsEmpty "$DESTINATION_FOLDER"

    local NEW_FILE_NAME=$(zenity --entry \
    --title="Nazwa pliku" \
    --text="Wprowadź nazwę nowego pliku:")
    exitIfInputIsEmpty "$NEW_FILE_NAME"

    if [[ $PROGRAM_MODE = $EDIT_VIDEO_MODE ]]; then
        NEW_FILE_NAME+=".mkv"
    elif [[ $PROGRAM_MODE = $EDIT_AUDIO_MODE ]]; then
        NEW_FILE_NAME+=".mp3"
    fi

    EDIT['destination']+="${DESTINATION_FOLDER}/${NEW_FILE_NAME} "
}

# ==============================
# Funkcje dotyczace edycji Wideo
# ==============================

# Pyta o wybranie formy edycji
chooseVideoEditOperation() {
    EDIT['operation']=$(zenity --list \
    --width=300 --height=200 \
    --radiolist \
    --title="Wybierz Operacje" \
    --text="" \
    --column="" --column="Opcja" \
    TRUE "$VIDEO_CUT_OPERATION" \
    FALSE "$VIDEO_EXTRACT_AUDIO" \
    FALSE "$VIDEO_CHANGE_VOLUME")
    exitIfInputIsEmpty "${EDIT['operation']}"
}

# Sprawdza czy przekazany do funkcji plik ma poprawne rozszerzenie
checkIfFileIsVideo() {
    if file -i "$1" | grep -q video  ; then
        return 0
    else
        return 1
    fi
}

# Pyta uzytkownika o wskazanie pliku do edycji
chooseVideoFile() {
    local FILE_PATH=$(zenity --file-selection --title="Wybierz Plik Wideo")
    exitIfInputIsEmpty "$FILE_PATH"

    checkIfFileIsVideo "$FILE_PATH"
    if [[ $? != 0 ]]; then
        showErrorDialog "$WRONG_FILE_FORMAT_MESSAGE"
        chooseVideoFile
    else
        EDIT['file-path']="$FILE_PATH"
    fi
}

# Sprawdza czy dlugosc wycinanego fragmentu
#nie przekracza dlugosci wideo
checkIfVideoTrimDontExceedVideoLength() {
    local START=$(echo "$TRIM_INFO" | cut -d " " -f1)
    local LENGTH=$(echo "$TRIM_INFO" | cut -d " " -f2)
    local START_H=$(echo "$START" | cut -d ":" -f1)
    local START_M=$(echo "$START" | cut -d ":" -f2)
    local START_S=$(echo "$START" | cut -d ":" -f3)
    local LENGTH_H=$(echo "$LENGTH" | cut -d ":" -f1)
    local LENGTH_M=$(echo "$LENGTH" | cut -d ":" -f2)
    local LENGTH_S=$(echo "$LENGTH" | cut -d ":" -f3)

    local TOTAL=$(($START_H*3600 + $START_M*60 + $START_S + $LENGTH_H*3600 + $LENGTH_M*60 + $LENGTH_S))
    local VIDEO_LENGTH=$(ffprobe -i "${EDIT['file-path']}" -show_format -v quiet | sed -n 's/duration=//p' | cut -d "." -f1)
    
    if [[ "$TOTAL" -gt "$VIDEO_LENGTH" ]]; then
        return 1
    fi
    return 0
}

# Pyta o dane potrzebne do przyciecia wideo
askForVideoTrimStartAndDuration() {
    local TRIM_INFO=$(zenity --forms --title="Wprowadź informacje o wycięciu" \
	--text="Wprowadź w formacie (hh:mm:ss)" \
	--separator=" " \
	--add-entry="Wytnij od: " \
	--add-entry="Długość wycinanego fragmentu: ")
    
    exitIfUserLeftProgram $?
    checkIfVideoTrimDontExceedVideoLength "$TRIM_INFO"
    local DONT_EXCEED=$?

    if ! [[ "$DONT_EXCEED" -eq 0 && "$TRIM_INFO" =~ ^[0-9]{2}:[0-5][0-9]:[0-5][0-9][[:space:]]{1}[0-9]{2}:[0-5][0-9]:[0-5][0-9]$ ]]; then
        showErrorDialog "$WRONG_INPUT_MESSAGE"
        askForVideoTrimStartAndDuration
    else
        EDIT['trim-start']=$(echo "$TRIM_INFO" | cut -d " " -f1)
        EDIT['trim-duration']=$(echo "$TRIM_INFO" | cut -d " " -f2)
    fi
}

# Przycina wideo
trimVideo() {
    zenity --info --width=300 --text="Wykonuje edycję" &
    local dialogIP=$!
    ffmpeg -ss ${EDIT['trim-start']} -i ${EDIT['file-path']} -t ${EDIT['trim-duration']} -vcodec copy \
    -acodec copy ${EDIT['destination']}
    local OPERATION_RESULT=$?
    kill $dialogIP
    showOperationResult "$OPERATION_RESULT"
}

# Wykonuje operacje potrzebne do przyciecia wideo
performVideoTrimOperation() {
    askForVideoTrimStartAndDuration
    trimVideo
}

# Oddziela audio z wideo
extractVideoAudio() {
    zenity --info --width=300 --text="Wykonuje edycję" &
    dialogIP=$!
    ffmpeg -i ${EDIT['file-path']} -vn ${EDIT['destination']}
    local OPERATION_RESULT=$?
    kill $dialogIP
    showOperationResult "$OPERATION_RESULT"  
}

# Wykonuje operacje potrzebne do oddzielenia audio z wideo
performVideoExtractAudioOperation() {
    extractVideoAudio
}

# Pyta jaka ma byc glosnosc edytowanego wideo
askForVideoNewVolume() {
    EDIT['video-volume']=$(zenity --forms --title="Wprowadź informacje o głośności" \
	--text="Wprowadź w nową głośność video w porównaniu do oryginału (1.5, 0.75, 0.5, etc.)" \
	--separator=" " \
	--add-entry="Głośność: ")
    exitIfUserLeftProgram $?

    if ! [[ "${EDIT['video-volume']}" =~ ^[0-9]{1}\.[0-9]{1,2}$ ]]; then
        showErrorDialog "$WRONG_INPUT_MESSAGE"
        askForVideoNewVolume
    fi
}

# Zmienia glosnosc wideo
adjustVideoVolume() {
    zenity --info --width=300 --text="Wykonuje edycję" &
    local dialogIP=$!
    ffmpeg -i ${EDIT['file-path']} -filter:a "volume=${EDIT['video-volume']}" -preset ultrafast ${EDIT['destination']}
    local OPERATION_RESULT=$?
    kill $dialogIP
    showOperationResult "$OPERATION_RESULT"  
}

# Wykonuje operacje potrzebne do edycji glosnosci wideo
performVideoVolumeOperation() {
    askForVideoNewVolume
    adjustVideoVolume
}

# UruVideoa poprawna operacje edycji
runProperVideoEditOperation() {
    if [[ "${EDIT['operation']}" = "$VIDEO_CUT_OPERATION" ]]; then
        performVideoTrimOperation
    elif [[ "${EDIT['operation']}" = "$VIDEO_EXTRACT_AUDIO" ]]; then
        performVideoExtractAudioOperation
    elif [[ "${EDIT['operation']}" = "$VIDEO_CHANGE_VOLUME" ]]; then
        performVideoVolumeOperation
    fi
}

# Glowna funkcja odpowiadajaca za edycje video
editVideo() {
    declare -A EDIT

    chooseVideoFile
    chooseVideoEditOperation
    chooseWhereStoreEditedFile
    runProperVideoEditOperation
}

# ==============================
# Funkcje dotyczace edycji Audio
# ==============================

# Sprawdza czy przekazany do funkcji plik ma poprawne rozszerzenie
checkIfAudioFormatIsCorrect() {
    # ukrywam wyjscie z operacji
    sox $1 -n stat > /dev/null 2>&1
    return $?
}

# Pyta uzytkownika o wskazanie pliku do edycji
chooseAudioFile() {
    local FILE_PATH=$(zenity --file-selection --title="Wybierz Plik Audio")
    exitIfInputIsEmpty "$FILE_PATH"

    checkIfAudioFormatIsCorrect "$FILE_PATH"
    if [[ $? != 0 ]]; then
        showErrorDialog "$WRONG_FILE_FORMAT_MESSAGE"
        chooseAudioFile
    fi

    FILE_PATH+=" "
    EDIT['file-path']="$FILE_PATH"
}

# Pyta o wybranie formy edycji
chooseAudioEditOperation() {
    EDIT['operation']=$(zenity --list \
    --width=300 --height=200 \
    --radiolist \
    --title="Wybierz Operacje" \
    --text="" \
    --column="" --column="Opcja" \
    TRUE "$AUDIO_CUT_OPERATION" \
    FALSE "$AUDIO_CHANGE_SPEED" \
    FALSE "$AUDIO_CHANGE_VOLUME")
    exitIfInputIsEmpty "${EDIT['operation']}"
}

# Sprawdza czy uzytkownik nie chce przyciac fragmentu wykraczajacego
# poza dlugosc nagrania
checkIfAudioTrimDontExceedAudioLength() {
    if ! [[ "${EDIT['trim-info']}" =~ ^[0-9]+[[:space:]]{1}[0-9]+$ ]]; then
        showErrorDialog "$WRONG_INPUT_MESSAGE"
        askForAudioTrimStartAndDuration
    else
        local START=$(echo "${EDIT['trim-info']}" | cut -d " " -f1)
        local LENGTH=$(echo "${EDIT['trim-info']}" | cut -d " " -f2)
        local TOTAL=$(($START+$LENGTH))
        local AUDIO_LENGTH=$(sox ${EDIT['file-path']} -n stat 2>&1 | sed -n 's#^Length (seconds):[^0-9]*\([0-9.]*\)$#\1#p')
        AUDIO_LENGTH=$(echo $AUDIO_LENGTH | cut -d "." -f1)
        if [[ "$TOTAL" -gt "$AUDIO_LENGTH" ]]; then
            showErrorDialog "$FILE_LENGTH_EXCEEDED"
            askForAudioTrimStartAndDuration
        fi
    fi
}

# Pyta o gdzie i o ile przyciac plik audio
askForAudioTrimStartAndDuration() {
    EDIT['trim-info']=$(zenity --forms --title="Wprowadź informacje o wycięciu" \
	--text="Wprowadź w sekundach" \
	--separator=" " \
	--add-entry="Wytnij od: " \
	--add-entry="Długość wycinanego fragmentu: ")

    exitIfUserLeftProgram $?
    checkIfAudioTrimDontExceedAudioLength
}

# Wykonuje operacje wyciecia fragmentu
trimAudio() {
    sox ${EDIT['file-path']} ${EDIT['destination']} trim ${EDIT['trim-info']}
    showOperationResult $?
}

# Wykonuje wszystkie operacje potrzebne do wyciecia audio
performAudioTrimOperation() {
    askForAudioTrimStartAndDuration
    trimAudio
}

# Pyta o to jak ma byc zmieniona predkosc audio
askForAudioNewSpeed() {
    EDIT['audio-speed']=$(zenity --forms --title="Wprowadź informacje o prędkości" \
	--text="Wprowadź w nową szybkość audio (1.5, 0.75, 0.5, etc.)" \
	--separator=" " \
	--add-entry="Prędkość: ")
    exitIfUserLeftProgram $?

    if ! [[ "${EDIT['audio-speed']}" =~ ^[0-9]{1}\.[0-9]{1,2}$ ]]; then
        showErrorDialog "$WRONG_INPUT_MESSAGE"
        askForAudioNewSpeed
    fi
}

# Zmienia predkosc audio
adjustAudioSpeed() {
    sox ${EDIT['file-path']} ${EDIT['destination']} speed ${EDIT['audio-speed']}
    showOperationResult $?
}

# Wykonuje wszystkie operacje potrzebne do zmiany predkosci audio
performAudioSpeedOperation() {
    askForAudioNewSpeed
    adjustAudioSpeed
}

# Pyta o to jak powinna byc zmieniona glosnosc
askForAudioNewVolume() {
    EDIT['audio-volume']=$(zenity --forms --title="Wprowadź informacje o głośności" \
	--text="Wprowadź w nową głośność audio w porównaniu do oryginału (1.5, 0.75, 0.5, etc.)" \
	--separator=" " \
	--add-entry="Głośność: ")
    exitIfUserLeftProgram $?

    if ! [[ "${EDIT['audio-volume']}" =~ ^[0-9]{1}\.[0-9]{1,2}$ ]]; then
        showErrorDialog "$WRONG_INPUT_MESSAGE"
        askForAudioNewVolume
    fi
}

# Dostosowuje glosnosc audio
adjustAudioVolume() {
    sox -v ${EDIT['audio-volume']} ${EDIT['file-path']} ${EDIT['destination']}
    showOperationResult "$?"
}

# Wykonuje zadania potrzebne do zmiany glosnosci audio
performAudioVolumeOperation() {
    askForAudioNewVolume
    adjustAudioVolume
}

# Uruchamia poprawna operacje edycji
runProperAudioEditOperation() {
    if [[ "${EDIT['operation']}" = "$AUDIO_CUT_OPERATION" ]]; then
        performAudioTrimOperation
    elif [[ "${EDIT['operation']}" = "$AUDIO_CHANGE_SPEED" ]]; then
        performAudioSpeedOperation
    elif [[ "${EDIT['operation']}" = "$AUDIO_CHANGE_VOLUME" ]]; then
        performAudioVolumeOperation
    fi
}

# Glowna funkcja odpowiadajaca za edycje audio
editAudio() {
    declare -A EDIT

    chooseAudioFile
    chooseAudioEditOperation
    chooseWhereStoreEditedFile
    runProperAudioEditOperation
}

# ============================
# Funkcje dotyczace pobierania
# ============================

# Pyta użytownika o typ audio jaki chce pobrać
askUserWhatDownloadedAudioFormatHeChoose() {
    local AUDIO_FORMAT=$(zenity --list \
    --width=300 --height=200 \
    --radiolist \
    --title="Wybierz Format Audio" \
    --text="" \
    --column="" --column="Format" \
    TRUE "mp3" \
    FALSE "wav" \
    FALSE "best" \
    FALSE "aac")
    DOWNLOAD['flags']+="--audio-format $AUDIO_FORMAT"
}

# Dodaje opcje potrzebne podczas pobierania pliku
handleAudioFileDownload() {
    DOWNLOAD['flags']+="-x "
    askUserWhatDownloadedAudioFormatHeChoose
}

# Wykonuje pobieranie
executeDownload() {
    youtube-dl "${DOWNLOAD['flags']}" "${DOWNLOAD['url']}" | 
    grep --line-buffered -oP '^\[download\].*?\K([0-9.]+\%|#\d+ of \d)' |
        zenity --progress \
    --title="Pobieranie" \
    --width="300" \
    --text="Pobieranie pliku trwa..." \
    --percentage=0 

    local PIPE_RESULTS=("${PIPESTATUS[@]}")

    if [[ ${PIPE_RESULTS[2]} != 0 ]]; then
        showErrorDialog "$UNSUCCESSFUL_OPERATION_MESSAGE"
    else
        showOperationResult ${PIPE_RESULTS[0]}
    fi
}

# Pyta użytkownika gdzie ma zostać zapisany nowy plik
askUserForDownloadFileDestination() {
    local DESTINATION_FOLDER=$(zenity --file-selection --title="Wybierz Katalog" --directory)
    exitIfInputIsEmpty "$DESTINATION_FOLDER"

    DESTINATION_FOLDER+="/"
    DOWNLOAD['flags']+="-o ${DESTINATION_FOLDER}%(title)s-%(id)s.%(ext)s "
}

# Pyta uzytkownika o link do pliku ktory ma byc pobierany
askUserForDownloadUrl() {
    DOWNLOAD['url']=$(zenity --entry \
    --width=500 \
    --title="Download URL" \
    --text="Podaj link wideo/audio do pobrania:" \
    --entry-text "")

    exitIfUserLeftProgram $?

    if [[ -z "${DOWNLOAD['url']}" ]]; then
        askUserForDownloadUrl
    elif ! [[ "${DOWNLOAD['url']}" =~ ^https://www.youtube.com/watch.* ]]; then
        showErrorDialog "$WRONG_LINK_MESSAGE"
        askUserForDownloadUrl
    fi
}

# Pobiera audio lub wideo z serwisu youtube
downloadFile() {
    declare -A DOWNLOAD

    askUserForDownloadUrl
    askUserForDownloadFileDestination

    if [[ "$PROGRAM_MODE" = "$DOWNLOAD_AUDIO_MODE" ]]; then
        handleAudioFileDownload
    fi    

    executeDownload
}

# ========================
# Ogólne funkcje programu
# ========================

# Uruchamia poprawny tryb programu, w zaleznosci od tego
# czy uzytkownik chce pobrac lub edytowac audio/video
runProperMode() {
    if [[ "$PROGRAM_MODE" = "$DOWNLOAD_VIDEO_MODE" || "$PROGRAM_MODE" = "$DOWNLOAD_AUDIO_MODE" ]]; then
        downloadFile
    elif [[ "$PROGRAM_MODE" = "$EDIT_VIDEO_MODE" ]]; then
        editVideo
    elif [[ "$PROGRAM_MODE" = "$EDIT_AUDIO_MODE" ]]; then
        editAudio
    fi
}

# Wyswietl pierwszy dialog pytajacy uzytkownika 
# jaka operacje chce przeprowadzic
askUserWhatProgramModeHeChoose() {
    PROGRAM_MODE=$(zenity --list \
    --width=300 --height=200 \
    --radiolist \
    --title="Wybierz Operacje" \
    --text="" \
    --column="" --column="Opcja" \
    TRUE "$DOWNLOAD_VIDEO_MODE" \
    FALSE "$DOWNLOAD_AUDIO_MODE" \
    FALSE "$EDIT_VIDEO_MODE" \
    FALSE "$EDIT_AUDIO_MODE")
}

# Glowna funkcja programu
startProgram() {
    askUserWhatProgramModeHeChoose
    runProperMode
}

startProgram