#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -fo|--folder)
    FOLDER="$2"
    shift # past argument
    shift # past value
    ;;
    -cs|--coversize)
    COVERSIZE="$2"
    shift # past argument
    shift # past value
    ;;
    -ic|--insertcover)
    INSERTCOVER="$2"
    shift # past argument
    ;;
    -ec|--extractcover)
    EXTRACTCOVER="$2"
    shift # past argument
    ;;
    -c|--convert)
    CONVERT=YES
    shift # past argument
    shift # past value
    ;;
    -n|--normalize)
    NORMALIZE=YES
    shift # past argument
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


## Funcions declaration ##

function help(){
echo """Music Manager script by Koboldo
This script is used for managing the audio files in a given folder.

Arguments:
-fo folder	Specifies the folder to work in. MANDATORY!!
-c format	Convert audio files into the format given.
		Formats available:
			- MP3
-cs nnnxnnn	Specifies the cover size. Note that this is formatted as widthxheight.
-ic         Inserts a cover. Image must:
                - Have the same name than the audio file.
                - Be in jpg format.
                - Stay in the same folder.
-ec     	Extracts all covers from audio files in folder.
-n	    	Normalizes the volume of all audio files in folder. Useful to give all files the same volume."""
}



function normalize {
	ffmpeg -i "$1" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp.txt 2>&1
	initialvolume=$(cat temp.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
	echo "Initial volume: ""$initialvolume"
	firstdigit=$(echo $initialvolume | cut -c 1)
	if [ $firstdigit == "-" ]; then
		if [ $(echo $initialvolume | cut -c 2) -gt 0 ]; then
			echo "Changing volume..."
			finalvolume=$(echo "$initialvolume" | sed "s/-//g")
			ffmpeg -loglevel panic -i "$1" -af "volume=""$finalvolume" temp.mp3
			rm "$1"
			mv temp.mp3 "$1"
			ffmpeg -i "$1" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
			volume=$(cat temp2.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
			echo "Final volume: ""$volume"
			rm temp.txt temp2.txt
		else
			echo "Volume already at maximum, skipping"
		fi
	else
		if [ $(echo $initialvolume | cut -c 1) -gt 0 ]; then
			echo "Changing volume..."
			finalvolume="-"$initialvolume
			ffmpeg -loglevel panic -i "$1" -af "volume=""$finalvolume" temp.mp3
			rm "$1"
			mv temp.mp3 "$1"
			ffmpeg -i "$1" -af "volumedetect" -vn -sn -dn -f null /dev/null > temp2.txt 2>&1
			volume=$(cat temp2.txt | grep max_volume | cut -d : -f 2 | cut -c 2-20 | sed "s/ //g")
			echo "Final volume: ""$volume"
			rm temp.txt temp2.txt
		else
			echo "Volume already at maximum, skipping"
		fi
	fi
}

function coversize {
	albuminfo=$(ffprobe -loglevel error -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 """$1""")
	ffmpeg -loglevel panic -i "$1" -an -vcodec copy cover.jpg
	initialcoverwidth=$(identify -format "%w" cover.jpg)
	initialcoverheight=$(identify -format "%h" cover.jpg)
	if [ "$initialcoverwidth" != "$initialcoverheight" ]; then
		echo "The cover size is not square."
		if [ ! -e "$albuminfo"".jpg" ]; then			
			mv cover.jpg "$albuminfo"".jpg"
			if [ ! -e "cover.tmp" ]; then
				touch "cover.tmp"
			fi
		else
			rm cover.jpg
		fi
	else
		if [ "$initialcoverwidth""x""$initialcoverheight" != "${COVERSIZE}" ]; then
			echo "The cover size is: " $initialcoverwidth"x"$initialcoverheight", resizing..."
			convert-im6.q16 cover.jpg -resize "${COVERSIZE}" cover_resized.jpg
			echo "Adding resized cover..."
			ffmpeg -loglevel panic -i "$1" -i cover_resized.jpg -map 0:0 -map 1:0 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" temp2.mp3
			rm "$1" cover.jpg cover_resized.jpg
			mv temp2.mp3 "$1"
		else
			echo "The cover is already at the selected size, skipping..."
			rm cover.jpg
		fi
	fi
}

function extractcover {
	ffmpeg -loglevel panic -i "$1" -an -vcodec copy "$1".jpg
}

function insertcover {
    filename=$(basename -- "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"
    echo "$filename"".jpg"
    cover="$filename"".jpg"
	echo "Inserting new album art..."
    if [ -f "$cover" ]; then
        mv "$1" audio.mp3
        ffmpeg -loglevel panic -i audio.mp3 -i "$cover" -map 0:0 -map 1:0 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" audio2.mp3
        mv audio2.mp3 "$1"
        rm audio.mp3
    else
        echo "Cover image not found. Skipping..."
    fi
}

function convertformat {
	filename=$(basename -- "$1")
	extension="${filename##*.}"
	filename="${filename%.*}"
	if [ "$extension" = "m4a" ]; then
		ffmpeg -loglevel panic -i "$1" -vn -ar 44100 -ac 2 -ab 192k -f mp3 temp.mp3
		rm "$1"
		mv temp.mp3 "$filename".mp3
	fi
}


## Start working ##

if [ -z "${FOLDER}" ]; then
	help
	exit
fi

echo FOLDER		= "${FOLDER}"
echo COVERSIZE		= "${COVERSIZE}"
echo INSERTCOVER	= "${INSERTCOVER}"
echo EXTRACTCOVER	= "${EXTRACTCOVER}"
echo NORMALIZE		= "${NORMALIZE}"
echo CONVERTFORMAT  = "${CONVERT}"

echo "Number of files to process:" $(ls -1 "${FOLDER}" | wc -l)

cd "${FOLDER}"

if [ ! -z ${CONVERT} ]; then
	echo
	echo "Converting files..."
	echo "---------------------------------"
	for file in *; do
		echo "File: ""$file"		
		convertformat "$file"
		echo
	done
	echo
fi

if [ ! -z ${NORMALIZE} ]; then
	echo
	echo "Normalizing files..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"		
		normalize "$file"
		echo
	done
	echo
fi

if [ ! -z ${INSERTCOVER} ]; then
	echo
	echo "Inserting album covers..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"
		insertcover "$file"
		echo
	done
	echo
fi

if [ ! -z ${EXTRACTCOVER} ]; then
	echo
	echo "Extracting album covers..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"
		extractcover "$file"
		echo
	done
	echo
fi

if [ ! -z ${COVERSIZE} ]; then
	echo
	echo "Changing album covers sizes..."
	echo "---------------------------------"
	for file in *.mp3; do
		echo "File: ""$file"		
		coversize "$file"
		echo
	done
	echo
	if [ -e "cover.tmp" ]; then
		echo "WARNING!"
		echo "Some covers are not square."
		echo "This can cause issues while showing in some devices."
		echo "Please, edit them with GIMP and insert them with the -ic option."
		rm "cover.tmp"
	fi
fi

cd ..


if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi
