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

# Uruchamia poprawny tryb programu, w zaleznosci od tego
# czy uzytkownik chce pobrac lub edytowac audio/video
runProperMode() {
    if [[ $PROGRAM_MODE = "Pobierz Wideo" || $PROGRAM_MODE = "Pobierz Audio" ]]; then
        downloadFile
    elif [[ $PROGRAM_MODE = "Edytuj Wideo" ]]; then
        editVideo
    elif [[ $PROGRAM_MODE = "Edytuj Audio" ]]; then
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
    TRUE "Pobierz Wideo" \
    FALSE "Pobierz Audio" \
    FALSE "Edytuj Wideo" \
    FALSE "Edytuj Audio")
}

# Glowna funkcja programu
startProgram() {
    askUserWhatProgramModeHeChoose
    runProperMode
}

startProgram